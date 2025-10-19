### 欧加真 SM8650/MT6989/MT6897 系列通用6.1内核自动化编译脚本
- 提供 Github Action 在线编译/shell本地编译双版本脚本。
#### 已实现：
- [x] 欧加真 SM8650 通用OKI内核（基于一加12 6.1.57/6.1.75/6.1.118 官方内核源码，其他同内核版本非SM8650机型可自行测试，部分机型可完全兼容）
- [x] 欧加真 MT6989 通用OKI内核（基于一加Ace5竞速版 6.1.115 官方内核源码，其他同内核版本非MT6989机型可自行测试，部分机型可完全兼容）
- [x] 欧加真 MT6897 通用OKI内核（基于一加平板 6.1.128 官方内核源码，其他同内核版本非MT6897机型可自行测试，部分机型可完全兼容）
- [x] SukiSU Ultra/KernelSU Next双版本KSU可选
- [x] 引入ccache缓存，优化工具链及编译流程，二次编译时间可缩短至约6min (注：首次使用ccache由于需要创建缓存速度会比较慢(约20-24min)，从第二次开始ccache才会生效加速编译，加速后单次编译时间约6~11min，具体时间随服务器负载情况而浮动；之后除非缓存出现问题，如无法加速等，可无需再清理ccache缓存)
- [x] 引入O2编译优化，改善内核运行性能
- [x] 可选manual/kprobes钩子模式：kprobes钩子模式下支持切换至sus su模式（类似面具的su实现，用于兼容一些程序的运行）
- [x] lz4 1.10.0 & zstd 1.5.7 算法更新&优化补丁(来自[@ferstar](https://github.com/ferstar), 移植by [@Xiaomichael](https://github.com/Xiaomichael))
- [x] 可选加入 BBR/Brutal 及一系列 tcp 拥塞控制算法
- [x] 三星SSG IO调度器移植（目前已知仅在一加12上会导致无法正常启动，原因尚不明确，待进一步研究修复）
- [x] 加入一些网络连接性能优化配置选项
- [x] 加入Re:Kernel支持，与Freezer，NoActive等软件配合降低功耗
- [x] 加入内核防格基带保护(By [@showdo](https://github.com/showdo))，有效防止恶意格机脚本/程序对系统分区数据的破坏
#### 待实现：
- [ ] 为非官方支持机型移植完整风驰内核支持（正在补全中）
- [ ] zram内置化，无需外置zram.ko挂载 ~~（有了新版 lz4&zstd 补丁真的还有必要吗）~~
- [ ] LXC/Docker 功能支持
- [ ] Nethunter 驱动移植
- [ ] 一加系列新版调度器移植（schedhorizon等）
- [ ] 欧加真 6.1 通用 GKI内核（移植一加f2fs源码，实现免清data刷入
- 更多优化与特性移植……
##### 
##### 
##### 
#### 鸣谢
- Sukisu Ultra：[SukiSU-Ultra/SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
- susfs4ksu：[ShirkNeko/susfs4ksu](https://github.com/ShirkNeko/susfs4ksu)
- SukiSU内核补丁：[SukiSU-Ultra/SukiSU_patch](https://github.com/SukiSU-Ultra/SukiSU_patch)
- pershoot维护的KernelSU Next分支：[pershoot/KernelSU-Next](https://github.com/pershoot/KernelSU-Next)
- KernelSU Next内核补丁：[WildKernels/kernel_patches](https://github.com/WildKernels/kernel_patches)
- 内核防格基带保护模块：[vc-teahouse/Baseband-guard](https://github.com/vc-teahouse/Baseband-guard)
- GKI 内核构建脚本：(待定)
