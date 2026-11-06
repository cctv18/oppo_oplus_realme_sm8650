#!/bin/bash
set -e

# ===== 获取脚本目录 =====
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ===== 设置自定义参数 =====
echo "===== 欧加真SM8650通用6.1.157 OKI内核本地编译脚本 By Coolapk@cctv18 ====="
echo ">>> 读取用户配置..."
MANIFEST=${MANIFEST:-oppo+oplus+realme}
read -p "请输入自定义内核后缀（默认：android14-11-o-g00d81d97d759）: " CUSTOM_SUFFIX
CUSTOM_SUFFIX=${CUSTOM_SUFFIX:-android14-11-o-g00d81d97d759}
read -p "是否启用susfs？(y/n，默认：y): " APPLY_SUSFS
APPLY_SUSFS=${APPLY_SUSFS:-y}
read -p "是否启用 KPM？(y-启用 KpatchNext独立kpm实现, n-关闭kpm，默认：y): " USE_PATCH_LINUX
USE_PATCH_LINUX=${USE_PATCH_LINUX:-y}
read -p "KSU分支版本(r=BakaSU(main/dev), s=BakaSU(sync-up), y=SukiSU Ultra, n=KernelSU Next, k=KSU, l=lkm模式(无内置KSU), 默认：r): " KSU_BRANCH
KSU_BRANCH=${KSU_BRANCH:-r}
read -p "是否应用 lz4 1.10.0 & zstd 1.5.7 补丁？(y/n，默认：y): " APPLY_LZ4
APPLY_LZ4=${APPLY_LZ4:-y}
read -p "是否应用 lz4kd 补丁？(y/n，默认：n): " APPLY_LZ4KD
APPLY_LZ4KD=${APPLY_LZ4KD:-n}
read -p "是否启用网络功能增强优化配置？(y/n，默认：n): " APPLY_BETTERNET
APPLY_BETTERNET=${APPLY_BETTERNET:-n}
read -p "是否添加 BBR 等一系列拥塞控制算法？(y添加/n禁用/d默认，默认：n): " APPLY_BBR
APPLY_BBR=${APPLY_BBR:-n}
read -p "是否添加 Droidspaces 容器支持？(n禁用/s标准/e扩展，默认：n): " APPLY_DROIDSPACES
APPLY_DROIDSPACES=${APPLY_DROIDSPACES:-n}
read -p "是否启用三星SSG IO调度器？(y/n，默认：n): " APPLY_SSG
APPLY_SSG=${APPLY_SSG:-n}
read -p "是否启用Re-Kernel？(y/n，默认：n): " APPLY_REKERNEL
APPLY_REKERNEL=${APPLY_REKERNEL:-n}
read -p "是否启用内核级基带保护？(y/n，默认：y): " APPLY_BBG
APPLY_BBG=${APPLY_BBG:-y}

if [[ "$KSU_BRANCH" == "y" || "$KSU_BRANCH" == "Y" ]]; then
  KSU_TYPE="SukiSU Ultra"
elif [[ "$KSU_BRANCH" == "r" || "$KSU_BRANCH" == "R" ]]; then
  KSU_TYPE="BakaSU (main/dev)"
elif [[ "$KSU_BRANCH" == "s" || "$KSU_BRANCH" == "S" ]]; then
  KSU_TYPE="BakaSU (sync-up)"
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  KSU_TYPE="KernelSU Next"
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  KSU_TYPE="KernelSU"
else
  KSU_TYPE="no KSU"
fi

echo
echo "===== 配置信息 ====="
echo "适用机型: $MANIFEST"
echo "自定义内核后缀: -$CUSTOM_SUFFIX"
echo "KSU分支版本: $KSU_TYPE"
echo "启用susfs: $APPLY_SUSFS"
echo "启用 KPM: $USE_PATCH_LINUX"
echo "应用 lz4&zstd 补丁: $APPLY_LZ4"
echo "应用 lz4kd 补丁: $APPLY_LZ4KD"
echo "应用网络功能增强优化配置: $APPLY_BETTERNET"
echo "应用 BBR 等算法: $APPLY_BBR"
echo "应用 Droidspaces 容器支持: $APPLY_DROIDSPACES"
echo "启用三星SSG IO调度器: $APPLY_SSG"
echo "启用Re-Kernel: $APPLY_REKERNEL"
echo "启用内核级基带保护: $APPLY_BBG"
echo "===================="
echo

# ===== 创建工作目录 =====
WORKDIR="$SCRIPT_DIR"
cd "$WORKDIR"

# ===== 安装构建依赖 =====
echo ">>> 安装构建依赖..."

SU() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        sudo "$@"
    fi
}

SU apt-mark hold firefox && apt-mark hold libc-bin && apt-mark hold man-db
SU rm -rf /var/lib/man-db/auto-update
SU apt-get update
SU apt-get install --no-install-recommends -y curl bison flex clang binutils dwarves git lld pahole zip perl make gcc python3 python-is-python3 bc libssl-dev libelf-dev cpio xz-utils tar unzip
SU rm -rf ./llvm.sh && wget https://apt.llvm.org/llvm.sh && chmod +x llvm.sh
SU ./llvm.sh 20 all

# ===== 初始化仓库 =====
echo ">>> 初始化 6.1.157 仓库..."
rm -rf kernel_workspace
mkdir kernel_workspace
cd kernel_workspace
git clone --depth=1 https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635 -b oneplus/sm8635_b_16.0.0_nord_5 common
cd common
# 移除 block/blk-mq.c 中多余导出的 test_task_ux 符号，防止与 vendor_boot 首阶段模块 oplus_bsp_sched_assist.ko 产生重复符号/CRC 冲突导致开机无限重启 (OnePlusOSS/android_kernel_common_oneplus_sm8650#35)
sed -i '/EXPORT_SYMBOL_GPL(test_task_ux);/d' block/blk-mq.c
if grep -q "EXPORT_SYMBOL_GPL(test_task_ux)" block/blk-mq.c; then
  echo "错误：未能移除 block/blk-mq.c 中的 EXPORT_SYMBOL_GPL(test_task_ux)！"
  exit 1
fi
# 修复 6.1.157 Nord 5 源码中 task_struct 的 KABI 槽位偏移错位问题 (CONFIG_SLIM_SCHED 将 dmabuf_info 从 slot 2 挤到 slot 4 导致开机无限重启)
python3 -c 'p="include/linux/sched.h"; s=open(p,encoding="utf-8").read(); old="\tANDROID_KABI_USE(1, unsigned int saved_state);\n#ifdef CONFIG_SLIM_SCHED\n\tANDROID_KABI_USE(2, unsigned long sched_prop);\n\tANDROID_KABI_USE(3, struct sched_ext_entity *scx);\n\tANDROID_KABI_USE(4, struct task_dma_buf_info *dmabuf_info);\n#else\n\tANDROID_KABI_USE(2, struct task_dma_buf_info *dmabuf_info);\n\tANDROID_KABI_RESERVE(3);\n\tANDROID_KABI_RESERVE(4);\n#endif"; new="\tANDROID_KABI_USE(1, unsigned int saved_state);\n\tANDROID_KABI_USE(2, struct task_dma_buf_info *dmabuf_info);\n#ifdef CONFIG_SLIM_SCHED\n\tANDROID_KABI_USE(3, unsigned long sched_prop);\n\tANDROID_KABI_USE(4, struct sched_ext_entity *scx);\n#else\n\tANDROID_KABI_RESERVE(3);\n\tANDROID_KABI_RESERVE(4);\n#endif"; assert old in s, "sched.h KABI pattern not found!"; open(p,"w",encoding="utf-8").write(s.replace(old,new,1))'
rm -rf drivers/soc/oplus/oplus_resctrl drivers/soc/oplus/storage kernel/locking/locking_main.h kernel/locking/oplus_locking.c kernel/locking/sa_common_struct.h kernel/oplus_cpu
wget -q https://github.com/cctv18/android_kernel_common_oneplus_sm8650/commit/1c9edfd50d2a.patch
python3 -c 'import re; p=open("1c9edfd50d2a.patch",encoding="utf-8").read(); p=re.sub(r"diff --git a/[^\n]+\ndeleted file mode 120000\n.*?(?=\ndiff --git |\Z)","",p,flags=re.S); open("1c9edfd50d2a.patch","w",encoding="utf-8").write(p)'
git apply -p1 1c9edfd50d2a.patch
rm -f 1c9edfd50d2a.patch
for rel in sched/sched_assist/sa_common.c sched/sched_assist/sa_common.h sched/sched_assist/sa_ddl.c sched/sched_assist/sa_fair.c sched/sched_assist/sa_oemdata.c sched/sched_assist/sched_assist.c waker_identify/waker_identify.c; do
  wget -q "https://raw.githubusercontent.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8635/oneplus/sm8635_b_16.0.0_nord_5/vendor/oplus/kernel/cpu/$rel" -O "kernel/oplus_cpu/$rel"
done
wget -q https://github.com/cctv18/android_kernel_common_oneplus_sm8650/commit/8cd9786cbcc5.patch && patch -p1 -F 3 < 8cd9786cbcc5.patch && rm -f 8cd9786cbcc5.patch
wget -q https://github.com/cctv18/android_kernel_common_oneplus_sm8650/commit/a7a67b52a514.patch && patch -p1 -F 3 < a7a67b52a514.patch && rm -f a7a67b52a514.patch
wget -q https://github.com/cctv18/android_kernel_common_oneplus_sm8650/commit/81bd0078c430.patch && patch -p1 -F 3 < 81bd0078c430.patch && rm -f 81bd0078c430.patch
cd ..
echo ">>> 初始化仓库完成"

# ===== 清除 abi 文件、去除 -dirty 后缀 =====
echo ">>> 正在清除 ABI 文件及去除 dirty 后缀..."
rm common/android/abi_gki_protected_exports_* || true

for f in common/scripts/setlocalversion; do
  sed -i 's/ -dirty//g' "$f"
  sed -i '$i res=$(echo "$res" | sed '\''s/-dirty//g'\'')' "$f"
done

# ===== 替换版本后缀 =====
echo ">>> 替换内核版本后缀..."
for f in ./common/scripts/setlocalversion; do
  sed -i "\$s|echo \"\\\$res\"|echo \"-${CUSTOM_SUFFIX}\"|" "$f"
done

# ===== 拉取 KSU 并设置版本号 =====
if [[ $KSU_BRANCH == [yYrR] ]]; then
  echo ">>> 拉取 BakaSU (main分支) 并设置版本（由于SukiSU长期未维护无法正常编译，且BakaSU兼容sukisu管理器，故SukiSU源码仓库已重定向为bakasu）..."
  curl -LSs "https://raw.githubusercontent.com/Baka-SU/BakaSU/main/kernel/setup.sh" | bash -s main
  echo 'CONFIG_KSU_FULL_NAME_FORMAT="%TAG_NAME%-%COMMIT_SHA%@cctv18"' >> ./common/arch/arm64/configs/gki_defconfig
  sed -i '/__maybe_static struct page \*fake_status = NULL;/a #if defined(KSU_COMPAT_HAS_SUSFS_FEATURE_SELINUX_HIDE) \&\& LINUX_VERSION_CODE < KERNEL_VERSION(6, 6, 0)\nstruct selinux_state fake_state;\n#endif' ./KernelSU/kernel/feature/selinux_hide.c
  sed -i '/no backup sepolicy available/{n;n;a #if defined(KSU_COMPAT_HAS_SUSFS_FEATURE_SELINUX_HIDE) \&\& LINUX_VERSION_CODE < KERNEL_VERSION(6, 6, 0)\n    fake_state.initialized = true;\n    fake_state.policy = backup_sepolicy;\n#endif
  }' ./KernelSU/kernel/feature/selinux_hide.c
  sed -i 's/-dirty//g' ./KernelSU/kernel/Kbuild
elif [[ "$KSU_BRANCH" == "s" || "$KSU_BRANCH" == "S" ]]; then
  echo ">>> 拉取 BakaSU (sync-up分支) 并设置版本..."
  curl -LSs "https://raw.githubusercontent.com/Baka-SU/BakaSU/refs/heads/sync-up/kernel/setup.sh" | bash -s sync-up
  echo 'CONFIG_KSU_FULL_NAME_FORMAT="%TAG_NAME%-%COMMIT_SHA%@cctv18"' >> ./common/arch/arm64/configs/gki_defconfig
  if ! grep -q "KSU_SUSFS_PRIORITY_UID_FILTER" ./KernelSU/kernel/Kconfig; then
    sed -i '/config KSU_SUSFS_SUS_MAP/i config KSU_SUSFS_PRIORITY_UID_FILTER\n    bool "Enable priority uid filter"\n    depends on KSU_SUSFS\n    default y\n' ./KernelSU/kernel/Kconfig
  fi
  sed -i 's/-dirty//g' ./KernelSU/kernel/Kbuild
elif [[ "$KSU_BRANCH" == "n" || "$KSU_BRANCH" == "N" ]]; then
  echo ">>> 拉取 KernelSU Next 并设置版本..."
  curl -LSs "https://raw.githubusercontent.com/pershoot/KernelSU-Next/refs/heads/dev-susfs/kernel/setup.sh" | bash -s dev-susfs
  cd KernelSU-Next
  rm -rf .git
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/pershoot/KernelSU-Next/commits?sha=dev&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/KSU_VERSION_FALLBACK := 1/KSU_VERSION_FALLBACK := $KSU_VERSION/g" kernel/Kbuild
  KSU_GIT_TAG=$(curl -sL "https://api.github.com/repos/KernelSU-Next/KernelSU-Next/tags" | grep -o '"name": *"[^"]*"' | head -n 1 | sed 's/"name": "//;s/"//')
  sed -i "s/KSU_VERSION_TAG_FALLBACK := v0.0.1/KSU_VERSION_TAG_FALLBACK := $KSU_GIT_TAG/g" kernel/Kbuild
  cd ../common/drivers/kernelsu
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/apk_sign.patch
  patch -p2 -N -F 3 < apk_sign.patch || true
elif [[ "$KSU_BRANCH" == "k" || "$KSU_BRANCH" == "K" ]]; then
  echo ">>> 拉取 KernelSU (tiann/KernelSU) 并设置版本..."
  curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/refs/heads/main/kernel/setup.sh" | bash -s main
  cd ./KernelSU
  KSU_VERSION=$(expr $(curl -sI "https://api.github.com/repos/tiann/KernelSU/commits?sha=main&per_page=1" | grep -i "link:" | sed -n 's/.*page=\([0-9]*\)>; rel="last".*/\1/p') "+" 30000)
  sed -i "s/DKSU_VERSION=16/DKSU_VERSION=${KSU_VERSION}/" kernel/Kbuild
else
  echo "已选择无内置KernelSU模式，跳过配置..."
fi

# ===== 克隆补丁仓库&应用 SUSFS 补丁 =====
cd "$WORKDIR/kernel_workspace"
echo ">>> 应用 SUSFS&hook 补丁..."
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo ">>> 克隆补丁仓库..."
  if [[ "$KSU_BRANCH" == [sS] ]]; then
    git clone --depth=1 https://gitlab.com/simonpunk/susfs4ksu.git susfs4ksu -b gki-android14-6.1
  else
    git clone --depth=1 https://github.com/cctv18/susfs4oki.git susfs4ksu -b oki-android14-6.1
  fi
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/69_hide_stuff.patch -O ./common/69_hide_stuff.patch
  grep -q "jdwp-control" ./common/69_hide_stuff.patch || wget https://github.com/RamuSriram/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/69_hide_stuff.patch -O ./common/69_hide_stuff.patch
  cp ./susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch ./common/
  cp ./susfs4ksu/kernel_patches/fs/* ./common/fs/
  cp ./susfs4ksu/kernel_patches/include/linux/* ./common/include/linux/
  cd ./common
  if [[ "$KSU_BRANCH" != [sS] ]]; then
    sed -i '/#include <trace\/hooks\/blk.h>/d' fs/namespace.c
    patch -p1 -F 3 < 50_add_susfs_in_gki-android14-6.1.patch || true
    sed -i '/#include "internal.h"/a #include <trace/hooks/blk.h>' fs/namespace.c
  else
    patch -p1 -F 3 < 50_add_susfs_in_gki-android14-6.1.patch || true
  fi
  patch -p1 -N -F 3 < 69_hide_stuff.patch || true
  grep -q "jdwp-control" net/unix/af_unix.c || { echo "错误：af_unix.c 隐藏补丁未生效！"; exit 1; }
else
  echo ">>> 未开启susfs，跳过susfs补丁配置..."
fi
cd "$WORKDIR/kernel_workspace"
if [[ "$KSU_BRANCH" == [kK] && "$APPLY_SUSFS" == [yY] ]]; then
  cp ./susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU/
  cd ./KernelSU
  patch -p1 -F 3 < 10_enable_susfs_for_ksu.patch || true
fi
cd "$WORKDIR/kernel_workspace"

# ===== 应用 LZ4 & ZSTD 补丁 =====
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  echo ">>> 正在添加lz4 1.10.0 & zstd 1.5.7补丁..."
  git clone --depth=1 https://github.com/cctv18/oppo_oplus_realme_sm8650.git
  cp ./oppo_oplus_realme_sm8650/zram_patch/001-lz4.patch ./common/
  cp ./oppo_oplus_realme_sm8650/zram_patch/lz4armv8.S ./common/lib
  cp ./oppo_oplus_realme_sm8650/zram_patch/002-zstd.patch ./common/
  cd "$WORKDIR/kernel_workspace/common"
  git apply -p1 < 001-lz4.patch || true
  patch -p1 -F 3 < 002-zstd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4&ZSTD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 应用 LZ4KD 补丁 =====
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  echo ">>> 应用 LZ4KD 补丁..."
  if [ ! -d "SukiSU_patch" ]; then
    git clone --depth=1 https://github.com/ShirkNeko/SukiSU_patch.git
  fi
  cp -r ./SukiSU_patch/other/zram/lz4k/include/linux/* ./common/include/linux/
  cp -r ./SukiSU_patch/other/zram/lz4k/lib/* ./common/lib
  cp -r ./SukiSU_patch/other/zram/lz4k/crypto/* ./common/crypto
  cp ./SukiSU_patch/other/zram/zram_patch/6.1/lz4kd.patch ./common/
  cd "$WORKDIR/kernel_workspace/common"
  patch -p1 -F 3 < lz4kd.patch || true
  cd "$WORKDIR/kernel_workspace"
else
  echo ">>> 跳过 LZ4KD 补丁..."
  cd "$WORKDIR/kernel_workspace"
fi

# ===== 添加 defconfig 配置项 =====
echo ">>> 添加 defconfig 配置项..."
DEFCONFIG_FILE=./common/arch/arm64/configs/gki_defconfig

# 写入通用 SUSFS/KSU 配置
echo "CONFIG_KSU=y" >> "$DEFCONFIG_FILE"
if [[ "$APPLY_SUSFS" == [yY] ]]; then
  echo "CONFIG_KSU_SUSFS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_KSU_SUSFS_SUS_MAP=y" >> "$DEFCONFIG_FILE"
  if [[ "$KSU_BRANCH" == [sS] ]]; then
    echo "CONFIG_KSU_SUSFS_PRIORITY_UID_FILTER=y" >> "$DEFCONFIG_FILE"
  fi
else
  echo "CONFIG_KSU_SUSFS=n" >> "$DEFCONFIG_FILE"
fi
echo "CONFIG_TMPFS_XATTR=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_TMPFS_POSIX_ACL=y" >> "$DEFCONFIG_FILE"
echo "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE=y" >> "$DEFCONFIG_FILE"
if [[ "$KSU_BRANCH" != [sS] ]]; then
  echo "CONFIG_HEADERS_INSTALL=n" >> "$DEFCONFIG_FILE"
fi

# 应用 CVE_2026_43499 修复补丁 (6.1.157 已内置，使用 -N || true)
cd common
wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/cve-2026-43499-rtmutex-6.1.patch
patch -p1 -N -F 3 < cve-2026-43499-rtmutex-6.1.patch || true
cd ..

if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  cat >> "$DEFCONFIG_FILE" <<EOF
CONFIG_ZSMALLOC=y
CONFIG_CRYPTO_LZ4HC=y
CONFIG_CRYPTO_LZ4K=y
CONFIG_CRYPTO_LZ4KD=y
CONFIG_CRYPTO_842=y
EOF
fi

if [[ "$APPLY_BETTERNET" == "y" || "$APPLY_BETTERNET" == "Y" ]]; then
  echo ">>> 正在启用网络功能增强优化配置..."
  echo "CONFIG_BPF_STREAM_PARSER=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_MAX=65534" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_BITMAP_PORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMARK=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTIP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_IPMAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_MAC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORTNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETNET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETPORT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_HASH_NETIFACE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP_SET_LIST_SET=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_NAT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IP6_NF_TARGET_MASQUERADE=y" >> "$DEFCONFIG_FILE"
  cd common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/other_patch/config.patch
  patch -p1 -F 3 < config.patch || true
  cd ..
fi

if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" || "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
  echo ">>> 正在添加 BBR 等一系列拥塞控制算法..."
  echo "CONFIG_TCP_CONG_ADVANCED=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BBR=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_CUBIC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_VEGAS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_NV=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_WESTWOOD=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_HTCP=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_TCP_CONG_BRUTAL=y" >> "$DEFCONFIG_FILE"
  if [[ "$APPLY_BBR" == "d" || "$APPLY_BBR" == "D" ]]; then
    echo "CONFIG_DEFAULT_TCP_CONG=bbr" >> "$DEFCONFIG_FILE"
  else
    echo "CONFIG_DEFAULT_TCP_CONG=cubic" >> "$DEFCONFIG_FILE"
  fi
fi

if [[ "$APPLY_DROIDSPACES" == [sSeE] ]]; then
  echo ">>> 正在添加 Droidspaces 容器支持..."
  echo "CONFIG_PID_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_IPC_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_USER_NS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_SYSVIPC=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_DEVTMPFS=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NAMESPACES=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_POSIX_MQUEUE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_ADDRTYPE=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_TARGET_LOG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NETFILTER_XT_MATCH_RECENT=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_NTSYNC=y" >> "$DEFCONFIG_FILE"
  cd common
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/droidspaces_patch/fix_sysvipc_kabi_6_7_8.patch
  patch -p1 -F 3 < fix_sysvipc_kabi_6_7_8.patch || true
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/droidspaces_patch/fix_oplus_bsp_midas.patch
  patch -p1 -F 3 < fix_oplus_bsp_midas.patch || true
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/droidspaces_patch/ntsync_base.patch
  wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/droidspaces_patch/ntsync_compat_android14-6.1.patch
  patch -p1 -F 3 < ntsync_base.patch || true
  patch -p1 -F 3 < ntsync_compat_android14-6.1.patch || true
  cd ..
  if [[ "$APPLY_DROIDSPACES" == [eE] ]]; then
    echo "正在启用容器环境扩展支持..."
    echo "CONFIG_BT_HCIVHCI=y" >> "$DEFCONFIG_FILE"
    echo "CONFIG_STATIC_USERMODEHELPER=n" >> "$DEFCONFIG_FILE"
    echo "CONFIG_DRM_LINDROID_EVDI=y" >> "$DEFCONFIG_FILE"
    cd common
    wget https://github.com/cctv18/oppo_oplus_realme_sm8650/raw/refs/heads/main/droidspaces_patch/evdi_drm.patch
    patch -p1 -F 3 < evdi_drm.patch || true
    cd ..
  fi
fi

if [[ "$APPLY_SSG" == "y" || "$APPLY_SSG" == "Y" ]]; then
  echo ">>> 正在启用三星SSG IO调度器..."
  echo "CONFIG_MQ_IOSCHED_SSG=y" >> "$DEFCONFIG_FILE"
  echo "CONFIG_MQ_IOSCHED_SSG_CGROUP=y" >> "$DEFCONFIG_FILE"
fi

if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  echo ">>> 正在启用Re-Kernel..."
  echo "CONFIG_REKERNEL=y" >> "$DEFCONFIG_FILE"
fi

if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  echo ">>> 正在启用内核级基带保护..."
  echo "CONFIG_BBG=y" >> "$DEFCONFIG_FILE"
  cd ./common
  curl -sSL https://github.com/cctv18/Baseband-guard/raw/master/setup.sh | bash
  sed -i '/^config LSM$/,/^help$/{ /^[[:space:]]*default/ { /baseband_guard/! s/selinux/selinux,baseband_guard/ } }' security/Kconfig
  cd ..
fi

echo ">>> 禁用 defconfig 检查..."
sed -i 's/check_defconfig//' ./common/build.config.gki

echo ">>> 开始编译内核..."
cd common
make -j$(nproc --all) LLVM=-20 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnuabeihf- CC=clang LD=ld.lld HOSTCC=clang HOSTLD=ld.lld O=out KCFLAGS+=-O2 KCFLAGS+=-Wno-error gki_defconfig
if [[ "$KSU_BRANCH" == [sS] ]]; then
  make -j$(nproc --all) LLVM=-20 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnuabeihf- CC=clang LD=ld.lld HOSTCC=clang HOSTLD=ld.lld O=out INSTALL_HDR_PATH="$(pwd)/out/usr" headers_install
fi
make -j$(nproc --all) LLVM=-20 ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnuabeihf- CC=clang LD=ld.lld HOSTCC=clang HOSTLD=ld.lld O=out KCFLAGS+=-O2 KCFLAGS+=-Wno-error all
if python3 -c 'd=open("out/arch/arm64/boot/Image","rb").read(); exit(0 if b"blk_mq_alloc_request\x00test_task_ux\x00" in d else 1)'; then
  echo "严重错误：Image 的 __ksymtab_strings 中仍然导出了 test_task_ux 符号！终止构建以防开机无限重启！"
  exit 1
fi
echo ">>> 内核编译成功并通过符号校验！"

OUT_DIR="$WORKDIR/kernel_workspace/common/out/arch/arm64/boot"
if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  echo ">>> 使用 kptools-linux 工具处理输出..."
  cd "$OUT_DIR"
  wget https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kptools-linux
  wget https://github.com/KernelSU-Next/KPatch-Next/releases/latest/download/kpimg-linux
  chmod +x ./kptools-linux
  ./kptools-linux -p -i ./Image -k ./kpimg-linux -o ./oImage
  rm -f Image
  mv oImage Image
  echo ">>> 已成功打上KP-N补丁!"
fi

cd "$WORKDIR/kernel_workspace"
echo ">>> 克隆 AnyKernel3 项目..."
git clone https://github.com/cctv18/AnyKernel3 --depth=1
rm -rf ./AnyKernel3/.git
cp "$OUT_DIR/Image" ./AnyKernel3/
cd "$WORKDIR/kernel_workspace/AnyKernel3"

if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  wget https://raw.githubusercontent.com/cctv18/oppo_oplus_realme_sm8650/refs/heads/main/zram.zip
fi

if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  wget https://github.com/cctv18/KPatch-Next/releases/latest/download/kpn.zip
fi

ZIP_NAME="Anykernel3-${MANIFEST}"
if [[ "$APPLY_SUSFS" == "y" || "$APPLY_SUSFS" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-susfs"
fi
if [[ "$APPLY_LZ4KD" == "y" || "$APPLY_LZ4KD" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4kd"
fi
if [[ "$APPLY_LZ4" == "y" || "$APPLY_LZ4" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-lz4-zstd"
fi
if [[ "$USE_PATCH_LINUX" == [yY] ]]; then
  ZIP_NAME="${ZIP_NAME}-kpm"
fi
if [[ "$APPLY_BBR" == "y" || "$APPLY_BBR" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbr"
fi
if [[ "$APPLY_DROIDSPACES" == [sSeE] ]]; then
  ZIP_NAME="${ZIP_NAME}-dss"
fi
if [[ "$APPLY_SSG" == "y" || "$APPLY_SSG" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-ssg"
fi
if [[ "$APPLY_REKERNEL" == "y" || "$APPLY_REKERNEL" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-rek"
fi
if [[ "$APPLY_BBG" == "y" || "$APPLY_BBG" == "Y" ]]; then
  ZIP_NAME="${ZIP_NAME}-bbg"
fi
ZIP_NAME="${ZIP_NAME}-v$(date +%Y%m%d).zip"

echo ">>> 打包文件: $ZIP_NAME"
zip -r "../$ZIP_NAME" ./*
ZIP_PATH="$(realpath "../$ZIP_NAME")"
echo ">>> 打包完成 文件所在目录: $ZIP_PATH"
