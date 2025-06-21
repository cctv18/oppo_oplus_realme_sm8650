# 欧加真 SM8650 通用内核自动化编译脚本
##### 
一个更方便、快捷的自动化OPPO/一加/真我系列骁龙8Gen3(SM8650)机型的通用内核编译脚本。
##### 
这个项目的初衷是解决以下问题：
- 绿厂官方摆烂，代码开源开一半，导致部分内核代码无法通过已有的配置xml正常编译，甚至没有编译配置xml；
- 官方使用的 Bazel 编译器过于不稳定且低效，容易出现各种各样莫名其妙的错误，且全网几乎找不到任何有效解决方法，对于新手极不友好；
- 由于绿厂魔改内核f2fs代码，导致欧加真机型刷入GKI内核后不清空data分区就无法正常开机。
## 本项目的主要内容
- 提供 OKI（官方源码）/ GKI（谷歌通用内核源码）双编译模式，OKI更稳定（保留官方驱动/调度），GKI可玩性更强（修改配置项更方便）；
- 为 GKI 移植了官方内核的f2fs源码，使 GKI 内核可以和官方 OKI 内核一样，刷入后可保留数据正常开机，不需要清空data ~~（新建文件夹）~~；
- 改用 LLVM/Clang 20 进行编译，并排除了官方源码中不必要的 vendor 源码参与，对比原 bazel 编译器缩短了近一半的编译时间，提高了编译过程的稳定性，输出日志更便于维护调试；
- 修复官方代码部分bug/未及时更新的补丁，并引入风驰内核驱动支持 ~~（待测试，尚不确定可以正常起效）~~；
- 提供 Github Action 在线编译/shell本地编译双版本脚本。
##### 
由于个人精力有限，本项目暂时仅提供 SukiSU Ultra 版 KernelSU 补丁，其余版本 KernelSU 支持将在后续更新 ~~（在咕了在咕了）~~。
## 计划实现功能
- [x] 欧加真 SM8650 通用A14 OKI内核（基于一加12 6.1.57 A14官方内核源码，适用于ColorOS 14/RealmeUI 5.0）
##### 
- [x] 欧加真 SM8650 通用A15 OKI内核（基于一加12 6.1.75/6.1.118 A15官方内核源码，适用于ColorOS 15/RealmeUI 6.0）
##### 
- [x] lz4 1.10.0算法更新&优化(来自@ferstar, 移植@Xiaomichael)
##### 
- [x] zstd更新&优化
##### 
- 增强功能：
- [ ] 为非官方支持机型移植完整风驰内核支持（正在补全中）
- [ ] 编译优化（ccache缓存，编译配置选项改进等）
- [ ] Wireguard/BBR/brutal 支持
- [ ] zram内置化（无需外置zram.ko挂载）
- [ ] 三星SSG IO调度器移植
- [ ] LXC/Docker 功能支持
- [ ] 一加系列新版调度器移植（schedhorizon等）
- 更多优化与特性移植……
##### 
- [ ] 欧加真 SM8650 通用A14/15 GKI内核（移植一加f2fs源码，实现免清data刷入）
##### 
- [ ] 原版KernelSU/KernelSU Next支持
##### 
- [ ] 将多版本内核编译脚本整合为一个脚本
## 鸣谢
- Sukisu Ultra：[SukiSU-Ultra/SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
- susfs4ksu：[ShirkNeko/susfs4ksu](https://github.com/ShirkNeko/susfs4ksu)
- SukiSU内核补丁：[SukiSU-Ultra/SukiSU_patch](https://github.com/SukiSU-Ultra/SukiSU_patch)
- GKI 内核构建脚本：[WildKernels/GKI_KernelSU_SUSFS](https://github.com/WildKernels/GKI_KernelSU_SUSFS)
- ~~本地化内核构建脚本（已失效）：[Suxiaoqinx/kernel_manifest_OnePlus_Sukisu_Ultra](https://github.com/Suxiaoqinx/kernel_manifest_OnePlus_Sukisu_Ultra)~~
- ~~风驰内核源码（不完整，修改中）：[HanKuCha/sched_ext](https://github.com/HanKuCha/sched_ext)~~
