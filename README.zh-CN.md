# 荣耀 Play（`COR-AL10` / Kirin 970）刷入 Android 14（`LeaOS 21.0 Google`）实战经验总结

[English](README.md) | **简体中文**

> **目标设备**：荣耀 Play 国行高配版（型号 `COR-AL10`，设备代号 `HWCOR`，SoC：海思麒麟 970，`arm64-v8a`，UFS 存储，`system = /dev/block/sdd62 / 2.97 GB (2,969,567,232 B)`，`userdata = /dev/block/sdd66 / 112 GB (120,586,240,000 B)`）  
> **起始状态**：Bootloader 已解锁（`verifiedbootstate=orange`），原厂 EMUI `9.1.0.350(C00E440R1P2)`（`Linux 4.9.148`，VNDK 28，`/` 与 `/vendor` 均为 EROFS），`recovery_ramdisk` 内已刷 Magisk `27.0`，`kernel` 为带 [212 字节 SELinux 解锁补丁](https://github.com/erha-erha/honor-play-emui9.1-350-selinux-kernel) 的原厂 `9.1.0.350` 内核（开机默认 Enforcing）。  
> **最终成果**：成功刷入 **Android 14**（`LeaOS 21.0` Google 版 / LineageOS 21 pre-QPR2，`UQ1A.240205.004`，EROFS）+ 麒麟 970 同平台 `SHRP-Reborn v3.2 charlotte` Recovery + 保留原厂 `9.1.0.350` 内核（无需另编 A14 内核）—— **90 秒直接点亮进桌面**，并完成常驻 **`Magisk v30.7`**、开机自启 **3 GiB LZ4 ZRAM**、**iOS 式运行态真墓碑（`LSPosed v1.11.0 + Frozen 8.3.0`）**、**`RebootNya` 免按键软重启**、**麒麟 970 + Mali-G72 60Hz 低延迟流畅度专项优化（`honorplay_smooth`）**、**相机 Scudo 闪退根治（`honorplay_camera_fix`）** 与 **有线 USB 调试永久自愈（`huawei_usb_adb_fix v1.2.0`）**。

---

## 目录

- [1. 实测可用软件、模块与镜像清单](#1-实测可用软件模块与镜像清单)
- [2. 阶段一：全分区备份、抢救原厂内核与还原纯净 Recovery](#2-阶段一全分区备份抢救原厂内核与还原纯净-recovery)
- [3. 阶段二：进 Fastboot 与修复 Windows 11 `HI3650`（`libwdi`）驱动占坑](#3-阶段二进-fastboot-与修复-windows-11-hi3650libwdi驱动占坑)
- [4. 阶段三：Fastboot 刷入 Android 14 与 `charlotte` 版 SHRP](#4-阶段三fastboot-刷入-android-14-与-charlotte-版-shrp)
- [5. 阶段四：核心复盘——为什么卡在 LineageOS 三个转圈（EMUI 9.1 跨机型 F2FS 通病）](#5-阶段四核心复盘为什么卡在-lineageos-三个转圈emui-91-跨机型-f2fs-通病)
- [6. 阶段五：在 SHRP 内正确重格 `/data` 与 90 秒开机验证](#6-阶段五在-shrp-内正确重格-data-与-90-秒开机验证)
- [7. 阶段六：刷后深度优化、相机闪退修复与有线 USB 调试永久自愈](#7-阶段六刷后深度优化相机闪退修复与有线-usb-调试永久自愈)
- [8. 开机后续事项与救砖回退方案](#8-开机后续事项与救砖回退方案)
- [9. 踩坑速查表](#9-踩坑速查表)
- [10. 致谢、版权声明与原作者署名](#10-致谢版权声明与原作者署名)

---

## 1. 实测可用软件、模块与镜像清单

> **高速镜像下载（GitHub Releases）**：
> - **基础刷机包**：**[Releases (`v1.0-mirror`)](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/tag/v1.0-mirror)**（含 `LeaOS 21.0`、`SHRP charlotte`、USB 驱动与 `SHA256SUMS.txt`）。
> - **Root / ZRAM / 真墓碑 / 流畅度优化包（仅限荣耀 Play / 麒麟 970）**：**[Releases (`v1.1-optimization`)](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/tag/v1.1-optimization)**（含本机专用 `honorplay_smooth`、`honorplay_zram3g`、`COR-AL10 9.1.0.350` Magisk v30.7 修补镜像，以及 GPLv3/Apache-2.0 开源上游工具镜像）。
> - **相机 Scudo 闪退修复与有线 USB 调试永久自愈包**：**[Releases (`v1.2-camera-usb-fix`)](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/tag/v1.2-camera-usb-fix)**（含本机专用 `honorplay_camera_fix-v1.0.0.zip` [仅限麒麟 970] + 通用 `huawei_usb_adb_fix-v1.2.0.zip` [EMUI 9.1 麒麟 970/710 通用] 与 `SHA256SUMS.txt`）。
> - **低延迟相位、4.2 万层挂载炸弹根治与 GMS Doze 进阶包（仅限荣耀 Play / 麒麟 970）**：**[Releases (`v1.3-lowlat-mountfix`)](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/tag/v1.3-lowlat-mountfix)**（含 `honorplay_smooth-v1.1.0.zip` [升级版：新增 `11.5ms` SF 低延迟相位减 `9.5ms` 触控滞后、根治 VNDK 28 `libminijail` 挂载炸弹、关 `traced`/FUSE 转码] + `honorplay_gms_doze-v1.0.0.zip` + `SHA256SUMS.txt`）。
> - **⚠️ 机型严格隔离提示**：机型专属模块（`honorplay_smooth`、`honorplay_zram3g`、`honorplay_camera_fix`）**仅适用于荣耀 Play（`COR-AL10` / 麒麟 970 / Mali-G72 / 6GB 内存）**，且均在 `customize.sh` 中内置了 `ro.hardware == kirin970` 防刷错校验。仅 `huawei_usb_adb_fix` 为 EMUI 9.1 通用 ConfigFS/FunctionFS 修复模块（已在麒麟 970 与麒麟 710 双机实测通过）。**华为畅享 9 Plus（麒麟 710 / Mali-G51 / 4GB 内存）** 请前往独立仓库 [huawei-enjoy9plus-a14-flash-guide](https://github.com/erha-erha/huawei-enjoy9plus-a14-flash-guide)。

| 用途 | 文件 / 工具 | 实测大小 | 目标分区 / 说明 | 原作者上游与高速镜像 |
| :--- | :--- | :--- | :--- | :--- |
| Android 14 ROM（带 GApps） | `LeaOS-21.0-20260118-iceows-google-pot.img.xz` → `.img` | 压缩包：`1,357,554,880` B<br>解压后：`2,197,798,912` B（~2.05 GiB） | 刷入 `system`（EROFS lz4，轻松塞进 2.77 GiB `system` 分区） | [@Iceows SourceForge](https://sourceforge.net/projects/altairfr-huawei/files/LeaOS-21.0/LeaOS-21.0-20260118-iceows-google-pot.img.xz/download) \| [v1.0 镜像](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.0-mirror/LeaOS-21.0-20260118-iceows-google-pot.img.xz) |
| 第三方 Recovery（麒麟 970 UFS） | `SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip` → `recovery.img` | 压缩包：`45,663,147` B<br>`recovery.img`：`27,068,416` B（~25.8 MiB） | 刷入 `recovery_ramdisk`（内置 Iceows 补丁版 `make_f2fs 1.14.0`） | [@Iceows SourceForge](https://sourceforge.net/projects/altairfr-huawei/files/SHRP-Recovery/SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip/download) \| [v1.0 镜像 (zip)](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.0-mirror/SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip) \| [预解压 `.img`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.0-mirror/SHRP-Reborn_v3.2_charlotte-recovery.img) |
| 内核 | 原厂 `9.1.0.350` `4.9.148` 内核（带 212 字节 SELinux 解锁补丁） | `25,165,824` B（24 MiB） | 保持原样不重刷，无需另行编译 A14 内核 | [@erha-erha/honor-play-emui9.1-350-selinux-kernel](https://github.com/erha-erha/honor-play-emui9.1-350-selinux-kernel) |
| Magisk Root（EMUI `9.1.0.350`） | `Magisk-v30.7.apk` 与 `COR-AL10_9.1.0.350_recovery_ramdisk_magisk307.img` | APK：`11.6 MB`<br>镜像：`33,554,432` B | 刷入 `recovery_ramdisk`（**仅限 `COR-AL10 9.1.0.350`**，`RECOVERYMODE=true`，`PREINITDEVICE=cache`） | [@topjohnwu/Magisk](https://github.com/topjohnwu/Magisk/releases) \| [v1.1 APK](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/Magisk-v30.7.apk) \| [v1.1 `.img`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/COR-AL10_9.1.0.350_recovery_ramdisk_magisk307.img) |
| 60Hz 流畅度、低延迟相位与防挂载炸弹（麒麟 970） | `honorplay_smooth-v1.1.0.zip`（[源码](modules/honorplay_smooth/)） | `4,774` B | Magisk 内直刷；HWUI 修复 + **`11.5ms` SF 低延迟相位（每帧减 `9.5ms`）** + **VNDK 28 `libminijail` 挂载炸弹根治** + 麒麟 970 调频 + 关 `dump-logs`/`traced`/FUSE 转码（默认保留窗口模糊） | [v1.3 下载](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.3-lowlat-mountfix/honorplay_smooth-v1.1.0.zip) |
| GMS Doze 深度休眠模块（可选） | `honorplay_gms_doze-v1.0.0.zip`（[源码](modules/honorplay_gms_doze/)） | `1,556` B | Magisk 内直刷；安装时从本机 `/product/etc/sysconfig/google.xml` 本地生成补丁让 GMS 进入 Doze 休眠（零闭源文件分发，随时可关） | [v1.3 下载](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.3-lowlat-mountfix/honorplay_gms_doze-v1.0.0.zip) |
| 3 GiB LZ4 ZRAM 模块（6GB 内存） | `honorplay_zram3g-v1.0.0.zip`（[源码](modules/honorplay_zram3g/)） | `1,630` B | Magisk 内直刷；每次带 Root 开机自动挂载 3 GiB LZ4 ZRAM | [v1.1 下载](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/honorplay_zram3g-v1.0.0.zip) |
| 相机 Scudo 闪退修复（仅限麒麟 970） | `honorplay_camera_fix-v1.0.0.zip`（[源码](modules/honorplay_camera_fix/)） | `2,448` B | Magisk 内直刷；开机自动从本机 `/odm/etc/camera/ippalgoconfig.xml` 生成补丁关闭 `SmartAE` 根治 `libSmartAE.so` 崩溃（零华为闭源文件分发） | [v1.2 下载](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.2-camera-usb-fix/honorplay_camera_fix-v1.0.0.zip) |
| 有线 USB 调试永久自愈（麒麟 970/710） | `huawei_usb_adb_fix-v1.2.0.zip`（[源码](modules/huawei_usb_adb_fix/)） | `3,811` B | Magisk 内直刷；覆盖 `manufacture,adb` 并以 0% 待机 CPU 事件监听自动自愈 `FUNCTIONFS_BIND` / `EBUSY` / `-12 ENOMEM` 死锁 | [v1.2 下载](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.2-camera-usb-fix/huawei_usb_adb_fix-v1.2.0.zip) |
| LSPosed 框架（Zygisk 版） | `LSPosed-v1.11.0-7209-zygisk-release.zip` | `6.79 MB` | 为 `Frozen` 提供 Android 14 系统框架 Hook | [@JingMatrix/Vector (LSPosed)](https://github.com/JingMatrix/Vector/releases) \| [v1.1 镜像](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/LSPosed-v1.11.0-7209-zygisk-release.zip) |
| 运行态真墓碑模块 | `Frozen8.3.0.zip` | `3.04 MB` | 类 iOS 后台挂起（`GLOBAL_SIGSTOP`，支持 `4.9.148` 内核 + A14） | [@MoWei-2077/FrozenVS](https://github.com/MoWei-2077/FrozenVS) \| [v1.1 镜像](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/Frozen8.3.0.zip) |
| 开源免按键重启工具 | `RebootNya_1.9.0.apk` | `3.01 MB` | 一键**软重启**（`setprop ctl.restart zygote`），免拔线免按键保留 Magisk | [@daisukiKaffuChino/RebootNya](https://github.com/daisukiKaffuChino/RebootNya/releases) \| [v1.1 镜像](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/RebootNya_1.9.0.apk) |
| 代理工具（可选） | `FlClash-0.9.4-android-arm64-v8a.apk` | `60.86 MB` | `arm64-v8a` 版本（记得在 Frozen 中加入白名单） | [@chen08209/FlClash](https://github.com/chen08209/FlClash/releases) \| [v1.1 镜像](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/FlClash-0.9.4-android-arm64-v8a.apk) |
| 刷机工具 / 备用驱动 | Google `adb` / `fastboot` `37.0.1` + `google_usb_driver.zip` | 驱动包：`8,682,859` B | 自动切分 5 个 sparse 分片匹配华为 `max-download-size`（450 MiB） | Android SDK Platform-Tools \| [v1.0 驱动镜像](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.0-mirror/google_usb_driver.zip) |

### 为什么 `iceows-google-pot.img` 可以直接刷在荣耀 Play（`COR-AL10`）上？
- Iceows 的 `LeaOS 21.0` 目录只按自己手头主力测试机命名发布了 `-pot`（P Smart 2019）和 `-ane`（P20 Lite），没有单独出 `-cor` 包。
- 实查 `Iceows/huawei-creator`（`android-14/run-huawei-emui9-ab-a14.sh`）与 `vndk-detect` 源码：
  - 华为 EMUI 9.1 的核心底层补丁（建 `/splash2`、`/modem_log`、`/preavs`、Kirin 显示/音频/CPU 属性、`tee_auth_daemon`、蓝牙 aptX、VNDK 28/29 兼容、4.9 无 BPF 兜底补丁）对所有 EMUI 9.1 机型**完全一致**。
  - `vndk-detect` 脚本明确包含 `kirin970` 分支，会自动开启华为 Overlay、相机与基带修复属性。
  - 真机实测 `COR-AL10` 的通信芯片同样是 `hisi / hi1102`（`ro.connectivity.chiptype=hisi`、`ro.connectivity.sub_chiptype=hi1102`），且原厂未启用 NFC（`ro.config.nfcdisabled=true`），因此 `pot` 的 AGPS/NFC 配置不会产生冲突。
  - 唯一视觉小瑕疵：进系统后“关于手机”里的机型会显示为 `POT-LX1`。
- **破除麒麟 970 的 EROFS 误区**：尽管 `huawei-creator` Issue #6 提到 EMUI 9.1 4.9 内核内置早期 EROFS（原厂 `system.img` 超级块 `compat=0x0`）与 `mkfs.erofs 1.5`（`compat=0x3`）存在版本差异，但在本机 `4.9.148` 内核下进入 SHRP 实测挂载 `mount -t erofs -o ro /dev/block/by-name/system` 直接返回 `rc=0`，读取压缩的 `framework.jar` 和 `init` 零报错，并最终 90 秒成功启动 Android 14。

---

## 2. 阶段一：全分区备份、抢救原厂内核与还原纯净 Recovery

趁机内尚有 EMUI 9.1 + Magisk `27.0` root 权限，动手前务必先将除 `userdata` 与 `cache` 外的全部分区备份到电脑。

### 2.1 Windows 下 `adb exec-out` 流式备份损坏的避坑
- **现象**：在 Windows 下直接通过 `adb exec-out "su -c 'dd if=/dev/block/by-name/<分区>'"` 重定向保存镜像，容易因为 `su` 标准输出/换行符转换导致文件多出几十到上百字节（实测 `nvme` 多出 133 字节，SHA-256 校验直接失败）。
- **稳妥做法**：在手机端先 `dd` 到 `/data/local/tmp/bak_<分区>.img`，再用 `adb -s <序列号> pull` 拉到电脑后删除临时文件，并逐一比对**手机端 `sha256sum` 与电脑端 `Get-FileHash`** 以及精确字节数（`blockdev --getsize64`）。
- **多设备安全习惯**：如果电脑同时开着模拟器或连了其他设备，所有 `adb` / `fastboot` 命令务必显式带 `-s <序列号>`。
- **备份结果**：共备份 67 个分区（约 6.73 GB），其中 **66 个分区 SHA-256 完全一致**，包含最关键的不可再生分区（`oeminfo`、`nvme`、`modemnvm_*`、`modem_*`、`system`、`vendor`、`product`、`recovery_ramdisk`、`kernel`）。仅 `splash2` 校验不一致，因为它是运行时 `rw` 挂载的实时日志分区，属于正常现象且不影响救砖。

### 2.2 格式化 `/data` 前先检查 `/data/local/tmp` 里的历史备份
- 清数据会彻底清空 `/data/local/tmp/`。刷前建议检查该目录，本次就在 `/data/local/tmp/kbackup/` 中抢救出了之前留存的原厂 `stock_kernel_350.img`、`stock_misc_350.img`、`stock_vbmeta_350.img` 和 `stock_recovery_ramdisk_magisk27.img`。

### 2.3 从现有 Magisk 27.0 镜像还原纯净原厂 `recovery_ramdisk`（备用）
EMUI 9.1 的 Magisk 刷在 `recovery_ramdisk` 中并保留了 `.backup/init.xz`，可用内置 `magiskboot` 对副本剥离面具、生成纯净原厂 Recovery 留作救砖备用：
```sh
mkdir -p /data/local/tmp/rec_restore && cd /data/local/tmp/rec_restore
cp /dev/block/by-name/recovery_ramdisk ./patched.img
/data/adb/magisk/magiskboot unpack patched.img
/data/adb/magisk/magiskboot cpio ramdisk.cpio restore
/data/adb/magisk/magiskboot repack patched.img stock_recovery_ramdisk.img
```

---

## 3. 阶段二：进 Fastboot 与修复 Windows 11 `HI3650`（`libwdi`）驱动占坑

### 3.1 `adb reboot bootloader` 无法进入 Fastboot
- **现象**：执行 `adb -s <序列号> reboot bootloader` 后，手机重启后仍直接回到正常 EMUI 系统。
- **正确进法**：
  1. **拔掉数据线**，将手机彻底关机。
  2. **按住「音量下键」不放**，同时插上连电脑的数据线，直到出现白底 `FASTBOOT&RESCUE MODE`（下方显示 `PHONE Unlocked`、`FRP Unlock`）再松手。

### 3.2 `fastboot devices` 为空、设备管理器显示 `HI3650`（`VID_18D1&PID_D00D`）
- **现象**：手机已在 Fastboot 模式（`USB\VID_18D1&PID_D00D`，兼容 ID 为标准 Fastboot 接口 `USB\Class_FF&SubClass_42&Prot_03`），但 `fastboot devices` 输出为空；设备管理器“通用串行总线设备（`USBDevice`）”下显示为 `HI3650`。
- **根因**：此前通过 Zadig / `libwdi` 安装过的 `hi3650.inf`（如 `oem46.inf`）占用了 `VID_18D1&PID_D00D`，它绑定的 WinUSB 缺少 `fastboot.exe` 枚举必需的 Google 接口 GUID（`{F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}`）。
- **为什么在设备管理器里“从磁盘安装 `android_winusb.inf`”会报错**：设备当前已被锁在 `USBDevice` 分类下，Windows 会直接拒绝 `AndroidUsbDeviceClass` 分类的 `android_winusb.inf`（提示“指定的文件夹没有包含设备的兼容软件驱动程序”）。
- **一行命令彻底解决（无需装未签名驱动）**：
  Windows 11 自带的微软签名 `winusb.inf`（同属 `USBDevice` 分类）其实**已经内置了 `{F72FE0D4-CBCB-407d-8814-9ED673D0DD6B}`**（对应 `ADB 设备`）。只需在 **管理员 PowerShell** 中强制删除占坑的 `libwdi` 驱动包即可：
  ```powershell
  # 1. 查出 hi3650.inf (Provider: libwdi) 对应的 oemXX.inf 编号
  pnputil /enum-drivers | Select-String -Context 1,5 "hi3650|libwdi"

  # 2. 强制卸载并删除（将 oem46.inf 替换为实际查到的编号）
  pnputil /delete-driver oem46.inf /uninstall /force
  ```
  删完后不用拔线重启，`fastboot devices` 立即正常识别出 `<序列号> fastboot`。

---

## 4. 阶段三：Fastboot 刷入 Android 14 与 `charlotte` 版 SHRP

1. 核对下载的 ROM 压缩包（`LeaOS-21.0-20260118-iceows-google-pot.img.xz` = `1,357,554,880` B），用 7-Zip 解压（CRC64 校验通过，得到 `2,197,798,912` B ≤ `2,969,567,232` B 的 `system` 分区容量，偏移 1024 处确认为 EROFS 魔数 `e2e1f5e0`）。
2. 从 `SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip` 解压出 `recovery.img`（`27,068,416` B ≤ 32 MiB，`ANDROID!` 头且 `kernel=0`，符合 EMUI 9.1 `recovery_ramdisk` 格式）。
3. 在 Fastboot 下刷入两个分区：
   ```powershell
   # 确认解锁状态
   fastboot -s <序列号> oem get-bootinfo
   # 预期输出：(bootloader) unlocked

   # 刷入 LeaOS 21.0 EROFS 系统镜像（自动切 5 个 sparse 分片，耗时 ~67.5s）
   fastboot -s <序列号> flash system LeaOS-21.0-20260118-iceows-google-pot.img

   # 刷入麒麟 970 SHRP-Reborn v3.2 Recovery（耗时 ~0.95s）
   fastboot -s <序列号> flash recovery_ramdisk recovery.img
   ```
   *(注意：华为 EMUI 9.1 **不要**刷空 `vbmeta`，也**不要**执行 `fastboot -w` 或 `fastboot erase userdata`。)*

---

## 5. 阶段四：核心复盘——为什么卡在 LineageOS 三个转圈（EMUI 9.1 跨机型 F2FS 通病）

### 5.1 故障现象
首次刷完 `system` 后，如果先用 **EMUI 9.1 原厂 Recovery** 执行“清除数据 → 恢复出厂设置（`yes`）”再重启，手机可以越过荣耀 Logo 并进入 **LineageOS 三个转圈开机动画**，但超过 5 分钟仍永远卡在转圈，无法进入桌面。

### 5.2 SHRP 实测证据（`dmesg` + `/sys/fs/pstore/pmsg-ramoops-0`）
刷入 `charlotte` 版 SHRP 并通过 `adb shell` 在本机 `4.9.148` 内核下实测挂载与读崩溃缓存，直接锁定了真因：

1. **`system`（EROFS `LeaOS 21.0`）挂载与读取完全正常**：
   ```text
   mount -t erofs -o ro /dev/block/by-name/system /tmp/t_sys  # rc=0
   erofs: read_super, device -> /dev/block/by-name/system
   sha256sum /tmp/t_sys/system/framework/framework.jar        # 正常读出哈希，零报错
   ```
2. **`userdata`（`sdd66`）挂载直接报 F2FS Superblock CRC 校验失败**：
   ```text
   mount: '/dev/block/by-name/userdata'->'/tmp/t_data': Invalid argument
   F2FS-fs (sdd66): Invalid checksum crc(0x100b1449)
   F2FS-fs (sdd66): Can't find valid F2FS filesystem in 1th superblock
   F2FS-fs (sdd66): Invalid checksum crc(0x100b1449)
   F2FS-fs (sdd66): Can't find valid F2FS filesystem in 2th superblock
   ```
3. **`/sys/fs/pstore/pmsg-ramoops-0` 还原了完整崩溃链**：
   ```text
   credstore main.cpp:49] Check failed: chdir(data_dir.c_str()) != -1 chdir: /data/misc/credstore: No such file or directory
   tombstoned failed to open directory: /data/tombstones: No such file or directory
   tombstoned received fatal signal 6
   ```

### 5.3 同类根因归纳（畅享 9 Plus 麒麟 710 vs 荣耀 Play 麒麟 970）
结合之前在 [华为畅享 9 Plus（`JKM-AL00b` / 麒麟 710）](https://github.com/erha-erha/huawei-enjoy9plus-a14-flash-guide) 上的实战对比，可以归纳出**华为/荣耀 EMUI 9.1 刷 Android 14 时的跨机型通用规律**：

- **为什么原厂 Recovery 格完必卡三圈**：EMUI 9.1 原厂 Recovery 格式化 `userdata` 时写入了华为新版/私有 F2FS 校验特性位（如 `sb_checksum` / `verity` / `quota_ino` / 华为私有加密标志），导致 GSI 启动阶段内核拒绝挂载 `/data`（`Invalid checksum crc`），而只读的 `system` 仍能拉起三个转圈动画，后台 `credstore` 和 `tombstoned` 因找不到 `/data` 目录陷入死循环崩溃。
- **为什么普通 TWRP / 上游 `mkfs.f2fs` 也不行**：上游 `f2fs-tools` 默认写入 `CP_NAT_BITS_FLAG`（NAT Bitmap 检查点页），华为 EMUI 9.1 的 4.9 内核 F2FS 驱动不兼容该标志位。只有 **Iceows 补丁版 `make_f2fs`**（通过 `0001-mkfs.f2fs-Remove-NAT-Bitmap-to-support-Huawei-EMUI9-.patch` 移除 NAT Bitmap 并配合 `-O encrypt`）才能格出既兼容 `/vendor/etc/fstab.kirin970`（`fileencryption=aes-256-xts:aes-256-cts`）又被 4.9 内核无报错挂载的 `userdata`。
- **麒麟 710 与麒麟 970 的异同对照**：

| 对比维度 | 华为畅享 9 Plus（`JKM-AL00b` / 麒麟 710） | 荣耀 Play（`COR-AL10` / 麒麟 970） |
| :--- | :--- | :--- |
| **`userdata` 节点** | `/dev/block/mmcblk0p70`（eMMC，~111 GB） | `/dev/block/sdd66`（UFS，~112 GB） |
| **原厂 Recovery 清数据后现象** | `F2FS-fs (mmcblk0p70): Invalid checksum crc` → `credstore` 崩溃 → 卡三圈 | `F2FS-fs (sdd66): Invalid checksum crc(0x100b1449)` → `credstore` / `tombstoned` 崩溃 → 卡三圈 |
| **所选 SHRP 版本** | `SHRP v3.1 potter`（`make_f2fs 1.13.0`） | `SHRP-Reborn v3.2 charlotte`（`make_f2fs 1.14.0`） |
| **ROM（`LeaOS-21.0-*-google-pot.img`）** | EROFS 正常挂载并启动 | EROFS 正常挂载并启动 |
| **内核要求差异** | 需同时刷 Iceows A14 内核（`Kirin710_EMUI9.1_PM`，补 `LOOP_CONFIGURE`）+ 重格 F2FS | 仅重格 F2FS 后即在原厂 `9.1.0.350` `4.9.148` 内核（带 212 字节 SELinux 补丁，默认 Enforcing 启动）上 **90 秒直接点亮** |

---

## 6. 阶段五：在 SHRP 内正确重格 `/data` 与 90 秒开机验证

1. **进入 SHRP Recovery**：
   - **先拔掉数据线**（插着线按组合键会进错成华为 **eRecovery**）。
   - 在 Fastboot 界面**同时长按「音量上键 + 电源键」一直不松手**（经过重启与解锁提示画面后继续按住音量上），直到进入 SHRP 界面。
   - 若提示 `Keep System Read Only?`，保持只读。进去后**重新插上数据线**（即便 `charlotte` SHRP 屏幕触摸与本机不完全匹配，USB 下的 `adb shell` 全程可用）。
2. **用 SHRP 内置的 Iceows `make_f2fs` 重格 `userdata` 并当场验证挂载**：
   ```sh
   # 先卸载 /data（若已挂载）
   umount /data 2>/dev/null || true

   # 用 Iceows 补丁版 make_f2fs (1.14.0) 格式化 userdata
   # 建议省略末尾扇区数让工具自动按本机 112 GB 分区容量格式化（切勿照抄其他机型的扇区数）
   /system/bin/make_f2fs -f -O encrypt -w 4096 /dev/block/by-name/userdata

   # 实测直接挂载验证——必须返回 0、容量约 112G 且 dmesg 无 Invalid checksum 报错
   mkdir -p /tmp/t_data
   mount -t f2fs /dev/block/by-name/userdata /tmp/t_data
   df -h /tmp/t_data
   dmesg | grep -iE "f2fs|sdd66|error|crc" | tail -10
   umount /tmp/t_data

   # 清空 /cache 并重启进 Android 14
   mkdir -p /tmp/t_cache
   mount /dev/block/by-name/cache /tmp/t_cache 2>/dev/null || true
   rm -rf /tmp/t_cache/* /cache/* 2>/dev/null || true
   umount /tmp/t_cache 2>/dev/null || true
   sync
   reboot
   ```
   预期挂载验证输出：
   ```text
   /dev/block/sdd66 112G 1.7G 111G 2% /tmp/t_data
   F2FS-fs (sdd66): F2fs successfully mounted with checkpoint version = ...
   ```
3. **首次开机实测结果（90 秒点亮）**：
   ```text
   ADB online at 90s!
   boot_completed=1  bootanim=stopped
   ro.build.version.release = 14
   ro.build.display.id      = lineage_arm64_byN-userdebug 14 UQ1A.240205.004 eng.iceows.20260118.143214 release-keys
   ro.product.model         = POT-LX1
   uname -a                 = Linux localhost 4.9.148 #1 SMP PREEMPT Thu Apr 15 02:23:51 CST 2021 aarch64
   /dev/block/sdd66         = 112G total, 110G avail
   ```

---

## 7. 阶段六：刷后深度优化、相机闪退修复与有线 USB 调试永久自愈

### 7.1 Magisk v30.7（`recovery_ramdisk`）与 EMUI 9.1 带 Root 开机 / 免按键软重启
- **刷入 Magisk v30.7**：EMUI 9.1 无独立 `boot` ramdisk，Magisk 需以 `RECOVERYMODE=true`、`KEEPVERITY=true`、`KEEPFORCEENCRYPT=true`、`PREINITDEVICE=cache` 修补原厂 `recovery_ramdisk` 后刷入（会覆盖 SHRP，日后随时可用 Fastboot 刷回 SHRP）：
  ```powershell
  adb -s <序列号> install -r Magisk-v30.7.apk
  # 仅限荣耀 Play COR-AL10 EMUI 9.1.0.350 使用！
  fastboot -s <序列号> flash recovery_ramdisk COR-AL10_9.1.0.350_recovery_ramdisk_magisk307.img
  ```
- **EMUI 9.1 冷开机精准松手时机**（彻底关机后首次引导进 Root）：
  1. **先拔掉数据线**（插线按音量上会被华为引导进 eRecovery）。
  2. 同时按住 **「音量上 + 电源键」** 不放，直到屏幕出现英文解锁警告（`Your device has been unlocked...`）。
  3. 此时可松开电源键，但 **「音量上」继续按住约 5 秒**，看到底部刚出现 **`Your device is booting now...`** 的瞬间 **立刻松开音量上**（松早了会退回 `enter_recovery=0` 普通无 Root 系统；按太久会进原厂 Recovery，⚠️ 切勿在原厂 Recovery 点清除数据）。
  4. 首次进桌面后打开 Magisk 管理器完成环境初始化（补齐 `/data/adb/magisk`）并开启 **Zygisk**。
- **日常免拔线、免按键重启方案（[`RebootNya v1.9.0`](https://github.com/daisukiKaffuChino/RebootNya)）**：
  - 华为 EMUI 9.1 闭源 Bootloader 在插 USB 线执行 `reboot recovery` 时容易跳转 eRecovery 或黑屏。
  - 日常 99% 的场景（装完 LSPosed 模块、修改系统框架）只需直接打开 **`RebootNya` →「软重启」**（执行 `setprop ctl.restart zygote`），实测 **6.5 秒完成**，**免拔线、免按实体键**，全程完整保留 `Magisk v30.7` 与 `3 GiB ZRAM`。

### 7.2 开机自启 3 GiB LZ4 ZRAM（`honorplay_zram3g`）vs 硬盘虚拟内存
- **为什么首选 ZRAM 而非闪存 Swap**：荣耀 Play 的 128 GB UFS 2.1（`KLUDG4U1EA-B0C1`）虽比 eMMC 快，但硬盘 Swap 仍有闪存写入损耗和毫秒级 I/O 抖动；**LZ4 ZRAM** 在内存内直接高速压缩冷页，速度达数 GB/s 且**零闪存损耗**。
- 在 Magisk 中刷入 [`honorplay_zram3g-v1.0.0.zip`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/honorplay_zram3g-v1.0.0.zip)（[源码](modules/honorplay_zram3g/)），每次带 Root 开机自动启用 `3 GiB`（`3,221,225,472` B）LZ4 ZRAM（`swapon -p 100`、`vm.page-cluster=0`、`vm.swappiness=80`）。

### 7.3 类 iOS 运行态真墓碑（`LSPosed v1.11.0 + Frozen 8.3.0`）
- **运行态真墓碑 vs 冰箱/雹**：冰箱/雹是通过 `pm disable` 停用并杀进程，重新点开需要冷启动；真墓碑是在应用切后台后将其进程挂起在内存中（**0% CPU 耗电**），再次点开图标时 **同 PID 原地毫秒级恢复**。
- **为什么选择 `Frozen 8.3.0`（`MoWei-2077/FrozenVS`）**：
  - 本机 Linux `4.9.148` 内核没有 **cgroup v2 `cgroup.freeze`**（因此 `Cirno` 与 Android 14 原生 `cached_apps_freezer` 无法使用 V2，上游 `freezeit v3.0.0` 也硬性拦截了 `< 5.10` 内核）。
  - `Frozen 8.3.0` 取消了 5.10 拦截并适配 Android 14（`targetSdk=34`），在 4.9 内核上自动启用 **`全局 SIGSTOP`** 模式（规避 4.9 cgroup v1 缺少 `freezer.killable` 导致的 `lmkd` 卡死风险），配合 **LSPosed 系统框架 Hook** 实现防 ANR 崩溃与点击瞬时唤醒。
- **部署与必加白名单**：
  1. Magisk 开启 **Zygisk**，依次刷入 `LSPosed-v1.11.0-7209-zygisk-release.zip` 与 `Frozen8.3.0.zip`。
  2. 重启后打开 **LSPosed 管理器 → 模块 → Frozen**，打开模块开关并确认勾选 **「系统框架（system）」**，再点 **RebootNya → 软重启**（6.5 秒生效）。
  3. **关键白名单**（在 Frozen「配置」中设为 `🍀自由后台`，或写入 `/data/adb/modules/Frozen/appcfg.txt` 如 `包名 40 1`）：务必放行代理工具（`com.follow.clash`）、输入法（`com.bytedance.android.doubaoime`）、谷歌服务框架（`com.google.android.gms` / `gsf`）、`Magisk` 以及微信等即时通讯软件。
- **实机验证结果**：Chrome、YouTube、Gmail、云端硬盘、谷歌翻译切后台后均自动进入内核 `T (stopped) / do_signal_stop` 零耗电挂起态；点开 YouTube 时**同 PID 原地秒恢复**，切走后再次自动挂起。

### 7.4 60Hz 流畅度与低延迟跟手调优（`honorplay_smooth` — 仅限麒麟 970）
- **硬件刷新率说明**：荣耀 Play LCD 屏幕物理上限就是 **`60.00 Hz`**（不支持 90/120Hz）。滑动不跟手与掉帧并非 60Hz 本身导致，而是实测抓到了 4 处系统瓶颈，现已全部打包进 [`honorplay_smooth-v1.0.0.zip`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/honorplay_smooth-v1.0.0.zip)（[源码](modules/honorplay_smooth/)）：
  1. **修复 `LeaOS 21.0` `/system/build.prop` 历史遗留图形属性**：原包内置的 `hwui.disable_vsync=true`、`debug.hwui.use_buffer_age=false`、`debug.egl.profiler=1`、`debug.hwui.profile=true` 导致每帧 `DequeueBuffer` 阻塞 `5.4–8.0 ms`、总延迟达 3 帧（`48.2 ms`）且强行全屏重绘。已通过 Magisk `system.prop` 修正，同时**特意保留华为 EMUI 9.1 HWC 2.2 必需的 `debug.sf.disable_backpressure=1` 与 `debug.sf.latch_unsignaled=1`**（若关闭这两项会导致桌面双图层围栏卡死跌至 14.5 FPS）。
  2. **修复麒麟 970 `interactive` 大核调频滞后 118ms**：优化 `policy0`（A53）与 `policy4`（A73）参数（采样周期 `12ms`、大核升频延迟降至 `10–15ms`、`io_is_busy=1`、`fast_ramp_down=0`）。
  3. **抬升 Mali-G72 GPU 唤醒起步档**：桌面滑动时原 GPU 锁在最低 `237 MHz` 导致单帧耗时 11–14ms；已将唤醒起步档小幅抬至中档 **`415 MHz`**（满频 `767 MHz`，空闲/息屏仍自动断电休眠，实测 GPU 仅 `27℃`）并切至 `scene=1`（`550 MHz` 加速档）。
  4. **关闭窗口模糊与后台调试日志**：启用 `disable_window_blurs=1`、`0.5x` 动画缩放，并自动停用可能残留的 `dump-logs` 调试服务。

| 实测指标（`dumpsys gfxinfo`，60Hz） | 优化前 | 刷入 `honorplay_smooth` 后 |
| :--- | :--- | :--- |
| 设置页每帧缓冲阻塞（`DequeueBuffer`） | `5.4–8.0 ms` | **`0.04 ms`**（降低约 150 倍） |
| 设置页中位帧耗时 / 掉帧率 | `21 ms` / 旧版 `98.6%` | **`15 ms` / `0.00%`（旧版 `9.8%`）** |
| 桌面滑动中位帧耗时 / 丢帧数 | `25–69 ms` / 频繁丢帧 | **`16 ms` / `0` 丢帧** |

### 7.5 相机闪退/卡顿修复（`honorplay_camera_fix` — 仅限麒麟 970）与全硬件实测清单
- **故障现象**：荣耀 Play（`COR-AL10`）刷完 `LeaOS 21.0`（Android 14）后，系统自带 LineageOS 相机（Aperture）无法连接或黑屏；谷歌相机精简版（GCam Go / `com.google.android.apps.cameralite`）虽然能出画面但极卡，像几秒一张的 PPT 截图。
- **实测根因（崩溃墓碑 + `/vendor/lib64/libSmartAE.so` 反汇编定位）**：
  - `initSmartAEAlgo`（`+0x154ec`）仅申请了 `0x77a00` 字节（`489,984 B`），但 `SmartAE::Init`（`+0x13610`）执行 `str wzr, [x20, #0xa00]` 写入了 `this + 0x77a00` 处——这是一个**原厂闭源库里潜伏多年的 4 字节堆溢出**。
  - 在 EMUI 9.1 的 `jemalloc` 分配器下，`0x77a00` 会向上对齐到 `512 KiB`（`0x80000`）内存档位，越界写入被静默吞掉；
  - 升级 Android 14 后系统换用 **Scudo** 安全分配器，该内存块右对齐紧贴 `PROT_NONE` 保护页，首帧初始化立刻触发 `SIGSEGV (SEGV_ACCERR)`，导致 `CameraDaemon` 每 5 秒崩溃重启一次（Aperture 报错退出，GCam Go 每重连一次只出一两帧截图）。
- **为什么关闭 `SmartAE` 比二进制打补丁更干净**：
  - A/B 实测对 `libSmartAE.so` 打 8 字节扩容补丁（`0x77a00 → 0x80000`）虽能止崩，但 `IppAlgoSmartAE` 在类原生 AOSP 下缺少华为私有场景元数据，仍会每 50ms 刷屏报错 `doSmartAEAlgo() failed to getSceneMode`。
  - [`honorplay_camera_fix-v1.0.0.zip`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.2-camera-usb-fix/honorplay_camera_fix-v1.0.0.zip)（[源码](modules/honorplay_camera_fix/)）在开机 `post-fs-data.sh` 阶段从本机原厂 `/odm/etc/camera/ippalgoconfig.xml` 本地生成副本并将 `SmartAE` 的 `switcher="1"` 改为 `"0"`，保留 `u:object_r:vendor_configs_file:s0` 上下文后直接 bind-mount 覆盖（因 `/odm` 为独立 EROFS 分区且无 `/system/odm` 软链，必须走 bind-mount，并配 `service.sh` 兜底）。结果：**零崩溃、零日志刷屏、每次开相机省 512 KiB 内存，且仓库与压缩包内不含任何华为闭源二进制或 XML 文件**。
- **全硬件实测矩阵（`COR-AL10` / 麒麟 970 + `LeaOS 21.0` + 原厂 `9.1.0.350` 内核 Enforcing）**：

| 硬件子系统 | 实测状态 | 实测详情 |
| :--- | :--- | :--- |
| **SoC / 内存 / UFS 闪存** | 正常 | 麒麟 970（`4×A53 + 4×A73`）、6GB 内存 + 3 GiB LZ4 ZRAM、128GB UFS 2.1 |
| **屏幕 / 触控 / 背光** | 正常 | 60.00 Hz LCD、触控与亮度平滑，配合 `honorplay_smooth` 满帧低延迟 |
| **前后双摄与闪光灯** | 正常 | 刷入 `honorplay_camera_fix-v1.0.0.zip` 后，Aperture 与 GCam Go 前后预览、拍照（2.4–7.6 MB）、前后硬件 H.264 录像（音画同步）、人像、夜景、手电筒（`0→128→0`）全通过，**零崩溃、零 SELinux AVC 拒绝** |
| **硬件视频编解码** | 正常 | `OMX.hisi.video.decoder/encoder`（AVC / HEVC）工作正常 |
| **音频 / 麦克风 / 3.5mm 耳机孔** | 正常 | `HI6403` 扬声器、听筒、麦克风、3.5mm 耳机孔均正常 |
| **Wi-Fi（2.4/5GHz）与蓝牙** | 正常 | `hi1102` 5GHz Wi-Fi 实测 292 Mbps / 0% 丢包；蓝牙 A2DP / HFP / BLE 就绪 |
| **蜂窝基带 / GPS / 指纹** | 正常 | 双卡巴龙基带（`21C20B369S016C000`）与 RIL HAL 就绪（插 SIM 卡后重启一次即可，不支持热插拔）；GNSS HAL 与 `Fingerprint21` HAL 就绪 |
| **传感器 / 震动 / RGB 呼吸灯 / USB** | 正常 | `lsm6ds3-c` 加速度/陀螺仪、`akm09918` 磁力计、`ltr578` 光距感、霍尔/计步、震动马达、RGB 通知灯、充电与有线 ADB（配合 `huawei_usb_adb_fix-v1.2.0.zip`） |
| **NFC / 红外遥控** | 无此硬件 | `COR-AL10` 出厂无 NFC / 红外发射器（`ro.config.nfcdisabled=true`） |

### 7.6 有线 USB 调试永久自愈方案（`huawei_usb_adb_fix v1.2.0`）
- **故障现象**：拔插数据线、长时间休眠，或在电脑上切换荣耀 Play 与畅享 9 Plus 两台华为/荣耀手机后，其中一台突然开启 USB 调试却完全无法被电脑识别（设备管理器连 `VID_12D1` 设备都不出现，仅显示充电），而无线调试正常。**经实测排查，这并非 Windows 多机驱动冲突！**
- **三层叠加根因（麒麟 970 与麒麟 710 EMUI 9.1 + `LeaOS 21.0` 完全一致）**：
  1. **原厂 `/vendor/default.prop` 默认值失效**：华为原厂写死了 `persist.sys.usb.config=manufacture,adb`，但 LeaOS 的 `init.usb.configfs.rc` 与 `init.hisi.usb.rc` 中均无对应触发规则。
  2. **Android 14 `adbd` 与 Linux 4.9 `f_fs.c` 的 `FUNCTIONFS_BIND` / `EBUSY` 死锁**：Android 14 APEX 的 `/apex/com.android.adbd/bin/adbd` 硬编码了 1 秒等待 `FUNCTIONFS_BIND` 超时（`timed out while waiting for FUNCTIONFS_BIND, trying again`，无属性可关）。拔插或休眠导致 `adbd` 关闭重开 `ep0` 时，若 `g1/UDC` 仍绑定着 `ff100000.dwc3`，`init` 重写 `UDC` 报 `EBUSY` 且 4.9 内核 `f_fs.c` 不再补发 `FUNCTIONFS_BIND`，`adbd` 陷入 1 秒死循环并导致 USB D+ 上拉电阻拉低（电脑完全感知不到设备，还会持续耗电）。
  3. **`ffs.adb` 实例中毒触发 `-12 ENOMEM`**：一旦卡入该状态，Linux 4.9 的 `ffs.adb` 实例即便走常规 `sys.usb.config none → adb` 也会持续报 `configfs-gadget ff100000.dwc3: failed to start g1: -12 (Out of memory)`，必须彻底卸载 `/dev/usb-ffs/adb`、删建 `/config/usb_gadget/g1/functions/ffs.adb` 并重挂 `functionfs` 才能恢复。
- **永久自愈模块（[`huawei_usb_adb_fix-v1.2.0.zip`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.2-camera-usb-fix/huawei_usb_adb_fix-v1.2.0.zip) / [源码](modules/huawei_usb_adb_fix/)）**：
  - `system.prop` 在启动早期直接将 `persist.sys.usb.config` 覆盖为 `adb`。
  - `usb_adb_guard.sh` 以 **0% 待机 CPU** 运行事件驱动监听（`logcat -b main -T 1 -v epoch adbd:W '*:S'`），通过 Unix 时间戳过滤历史日志、**检测到 `UDC == configured` 时自动跳过绝不打断正常传输**、直接读取 `/proc/mounts`（规避 `toybox mount` 无参扫描 Magisk 挂载表导致 99% CPU 死循环的巨坑），在检测到真实卡死后自动重建 `ffs.adb` 并恢复原有 USB 模式（`adb` / `mtp,adb` 等）。
  - **双机实测验证**：荣耀 Play 实测待机 0% CPU 且健康连接下触发注入安全跳过；畅享 9 Plus 在真实爆发 `FUNCTIONFS_BIND`/`EBUSY` 断连现场装入 v1.2.0 后，**零人工干预 12 秒内自动自愈**并被 Windows 自动枚举出 `USB\VID_12D1&PID_103A`。

### 7.7 低延迟 VSync 相位（`-9.5 ms`）、`libminijail` 4.2 万层挂载炸弹根治（`-1.63 GB` 内核内存）与 GMS Doze（`v1.3`）
- **揪出并根治上游 TrebleDroid / LeaOS VNDK 28 隐藏大坑（`libminijail.so` 指数挂载炸弹）**：
  - **实测根因**：原厂 LeaOS `/system/bin/phh-on-boot.sh` 与 `/system/bin/phh-on-data.sh` 每次开机及软重启（`ctl.restart zygote`）都会无条件叠挂 `libminijail.so`，且把文件自挂到了指向 `/apex/com.android.vndk.v28` 的软链 `/system/lib*/vndk-28/libminijail.so`（与源路径同属共享挂载对等组）。经历 ~10 次软重启后按 `2^N` 指数爆炸（`4,096 / 8,191` 层），导致 `/proc/mounts` 膨胀至 **`42,312` 条**、白吃约 **`1.63 GB` 内核内存**，且每次挂载变动都触发 PID 1 `init` 持续飙至 **`96.6%` CPU**！
  - **永久修复（已内置于 [`honorplay_smooth-v1.1.0.zip`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.3-lowlat-mountfix/honorplay_smooth-v1.1.0.zip)）**：通过 Magisk 覆盖修复版 `phh-on-boot.sh` 与 `phh-on-data.sh`（严格保留 `u:object_r:phhsu_exec:s0` 标签），移除自挂语句并加 `grep -q " $2 " /proc/mounts` 幂等判断。冷启动实测：`/proc/mounts` 从 **`42,312` 骤降至 `1,360` 条（`libminijail` 从 `40,956` 降至 `3`）**、内核内存从 **`2,101 MB` 降至 `470 MB`（立省 `1.63 GB`）**、`init` 回归 **`0%`**。
- **压低滑屏触控到上屏延迟（`-9.5 ms/帧`）**：
  - 实测桌面左右滑屏逐帧 `framestats` 发现：应用绘制仅 `6.4 ms`，但 `DisplayPresentTime` 上屏却滞后 **`48–64.6 ms`（3–4 帧）**，原因是未配相位偏移导致 SurfaceFlinger 落入 `app=2ms / SF=2ms` 默认档（`SF duration = 14.67 ms`，整条管线 `31.34 ms`）。
  - 实机反推出本机 `SurfaceFlinger` 无跨帧回绕条件（必须满足 `sf_phase >= app_phase`，否则回绕反而多加一帧），现调校为 **`app=11.5ms / SF=11.5ms`（GL 合成档 `10.0ms / 10.0ms`）**：`SF duration` 从 `14.67 ms` 降至 **`5.17 ms`**（GL `6.67 ms`），整条管线从 **`31.34 ms` 降至 `21.84 ms`（每帧净减 `9.5 ms`）**，同时完整保留 `16.67 ms` 应用绘制预算及原厂 `/vendor/build.prop` 必需的 `debug.sf.latch_unsignaled=1`。
- **GMS Doze、去追踪/转码与 ART 预编译（兼避坑）**：
  - [`honorplay_gms_doze-v1.0.0.zip`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.3-lowlat-mountfix/honorplay_gms_doze-v1.0.0.zip)（[源码](modules/honorplay_gms_doze/)）：安装时本地复制并注释本机 `/product/etc/sysconfig/google.xml` 中的 `com.google.android.gms` 省电白名单（零闭源文件分发），开机由 Magisk 自动挂载让 GMS 进入 Doze 休眠。
  - `honorplay_smooth-v1.1.0.zip` 同时关停后台 Perfetto 追踪（`persist.traced.enable=0`）与 FUSE 媒体软件转码（`persist.sys.fuse.transcode_enabled=false`），默认**保留毛玻璃窗口模糊**；⚠️ **切勿设置全局 `persist.log.tag=E`**（会屏蔽 `adbd:W` 导致 `huawei_usb_adb_fix` 自愈失明），且原厂 `4.9.148` 内核无 `/proc/pressure`（`CONFIG_PSI`），各种 PSI 类 LMKD 参数均无效。
  - 推荐刷机后执行一次 ART 分层编译与 UFS 2.1 块回收（`COR-AL10` 为 128GB 存储余量充足）：
    ```sh
    adb shell pm trim-caches 4096G && adb shell pm art cleanup
    adb shell cmd package compile -m speed-profile -a
    adb shell cmd package compile -m speed -f com.android.settings
    adb shell sm fstrim
    ```

---

## 8. 开机后续事项与救砖回退方案

- **国内首次初始化、Play 商店与 SIM 卡热插拔注意事项**：
  - `LeaOS 21.0` 默认开启 `WITH_ADB_INSECURE=true`，开机后有线 ADB 直接可用。
  - 若国内无外网导致 Google 开机向导卡在“正在准备我的设备”，先**离线跳过 Wi-Fi** 进桌面，再用 `adb install` 装代理软件后登录 Google。
  - 若遇 Play 商店首次后台自更新时点“安装”无反应（`adb shell am force-stop com.android.vending`）或 EMUI 9.1 巴龙基带热插拔 SIM 卡无信号（插好卡重启一次手机），可参考 [huawei-enjoy9plus-a14-flash-guide 阶段四](https://github.com/erha-erha/huawei-enjoy9plus-a14-flash-guide/blob/main/README.zh-CN.md#5-%E9%98%B6%E6%AE%B5%E5%9B%9B%E5%9B%BD%E5%86%85%E6%97%A0%E5%A4%96%E7%BD%91%E5%88%9D%E5%A7%8B%E5%8C%96%E4%BB%A3%E7%90%86%E9%85%8D%E7%BD%AEgoogle-%E5%A5%97%E4%BB%B6%E4%B8%8E-sim-%E5%8D%A1%E6%8E%92%E5%9D%91)。
- **随时退回原厂 EMUI `9.1.0.350`**：
  - 在 Fastboot 下刷回之前备份的 `system.img`、`stock_recovery_ramdisk.img`（及按需刷回 `stock_kernel_350.img`），再进原厂 Recovery 恢复出厂设置即可。
  - **严禁**用 `fastboot flash` 直接刷写 `oeminfo` / `nvme`，此类基带与机型分区仅在确需救砖时由 root 下 `dd` 慎重恢复。

---

## 9. 踩坑速查表

| 现象 / 报错 | 实际根因 | 解决方案 |
| :--- | :--- | :--- |
| Windows 下 `adb exec-out su -c dd` 备份 SHA-256 不一致 | `su` 标准输出换行/PTY 处理污染二进制流 | 先在手机端 `dd` 到 `/data/local/tmp`，再 `adb -s <序列号> pull` 后核对 SHA-256 |
| 备份时仅 `splash2.img` SHA-256 校验失败 | `/splash2` 为系统运行时 `rw` 挂载的实时日志分区 | 正常现象，忽略即可 |
| `adb reboot bootloader` 直接重启回正常 EMUI | EMUI / Magisk `recovery_ramdisk` 忽略软件重启到 bootloader 参数 | 拔线关机后，**按住音量下键不放插数据线**手动进 Fastboot |
| `fastboot devices` 为空、设备管理器显示 `HI3650` | 之前 Zadig/`libwdi` 装的 `hi3650.inf` 占用 `VID_18D1&PID_D00D`，缺 `{F72FE0D4-...}` GUID 且锁死 `USBDevice` 分类 | 管理员 PowerShell 执行 `pnputil /delete-driver oemXX.inf /uninstall /force`，回退到 Win11 自带 `winusb.inf` |
| 按音量上 + 电源进了 eRecovery 或未加载 Magisk | 没拔掉 USB 线，或音量上松早了/按太久 | **先拔线**；进 Magisk 在刚出现 `Your device is booting now...` 时松开音量上；日常重载模块直接用 **RebootNya → 软重启** |
| 刷完 A14 卡在 LineageOS 三个转圈超 5 分钟 | EMUI 9.1 原厂 Recovery 格出的 F2FS 触发 `F2FS-fs (sdd66): Invalid checksum crc` → `/data` 未挂载 → `credstore` 无限崩溃 | 刷 `SHRP-Reborn v3.2 charlotte`，执行 `/system/bin/make_f2fs -f -O encrypt -w 4096 /dev/block/by-name/userdata` 并实测 `mount -t f2fs` 后清 `/cache` 重启 |
| 首次开机向导卡在“正在准备我的设备” | 国内无外网导致 Google 联网检查超时 | 离线跳过 Wi-Fi 进桌面，有线 ADB 装代理后再登录 Google |
| 刷完 `LeaOS 21.0` 滑动掉帧、手感发粘不跟手 | LeaOS `/system/build.prop` 开启了 `hwui.disable_vsync=true`、`use_buffer_age=false`、`egl.profiler=1` 且麒麟 970 CPU/GPU 调频滞后 | 在 Magisk 刷入 `honorplay_smooth-v1.0.0.zip`（切勿关闭华为 HWC 2.2 的 `disable_backpressure=1` 与 `latch_unsignaled=1`） |
| 若强行设置 `debug.sf.use_phase_offsets_as_durations=1` 导致黑屏循环 | 与本机 `ro.surface_flinger.vsync_event_phase_offset_ns` 冲突触发 `WorkDuration` 断言崩溃 | 严禁在 LeaOS 21.0 上设置 `debug.sf.use_phase_offsets_as_durations=1` |
| 系统相机黑屏报错、GCam Go 像 PPT 截图极卡（`COR-AL10`） | `libSmartAE.so` `SmartAE::Init +0x77a00` 4 字节堆溢出撞上 Android 14 Scudo 保护页触发 `SIGSEGV`，`CameraDaemon` 每 5 秒崩溃重启 | Magisk 刷入 `honorplay_camera_fix-v1.0.0.zip`（仅限麒麟 970；自动本地关闭 `ippalgoconfig.xml` 内 `SmartAE`） |
| 有线 USB 调试突然消失（只充电，设备管理器无 `VID_12D1`） | `/vendor/default.prop` 残留 `manufacture,adb` + A14 `adbd` 与 4.9 `f_fs.c` `FUNCTIONFS_BIND` / `EBUSY` / `ffs.adb -12 ENOMEM` 死锁（非电脑驱动冲突） | Magisk 刷入 `huawei_usb_adb_fix-v1.2.0.zip` 实现 0% CPU 永久自愈（切勿设全局 `persist.log.tag=E`） |
| 多次软重启后 PID 1 `init` 吃满 `96%` CPU、`/proc/mounts` 破 4 万条 | 上游 `phh-on-boot.sh`/`phh-on-data.sh` 无幂等判断叠挂 `libminijail.so` 引发 `2^N` 挂载爆炸（泄漏 ~1.6GB 内核内存） | 刷入 `honorplay_smooth-v1.1.0.zip` 后冷重启一次即可彻底清零并根治 |
| 60 FPS 下左右滑屏仍感发粘不跟手 | 默认 SF 相位（`app=2ms/SF=2ms`）管线达 `31.34 ms`（实测上屏滞后 `48–64 ms`） | 刷入 `honorplay_smooth-v1.1.0.zip`（`11.5ms/11.5ms` 无回绕低延迟相位每帧净砍 `9.5 ms`） |

---

## 10. 致谢、版权声明与原作者署名

本仓库 GitHub Releases 中镜像的第三方开源软件均为**未经修改的官方原版发布包**，仅用于方便社区玩家高速下载；所有版权归原作者所有并遵循其原开源协议。闭源或未声明再分发许可的软件不作镜像，仅提供官方原地址链接。

| 项目 / 组件 | 原作者 | 上游仓库 / 官方地址 | 开源协议 |
| :--- | :--- | :--- | :--- |
| **LeaOS 21.0 (Android 14 GSI)** 与 **EMUI 9 F2FS `make_f2fs` 补丁** | **[@Iceows](https://github.com/Iceows)**（AltairFR） | [Iceows/huawei-creator](https://github.com/Iceows/huawei-creator) \| [SourceForge](https://sourceforge.net/projects/altairfr-huawei/) | 开源（LineageOS / Apache-2.0 / GPL） |
| **SHRP-Reborn v3.2** | **Team SHRP** & **[@Iceows](https://github.com/Iceows)** | [SHRP-Reborn](https://github.com/SHRP-Reborn) \| [SourceForge](https://sourceforge.net/projects/altairfr-huawei/files/SHRP-Recovery/) | GPL-3.0 |
| **Magisk v30.7** | **[@topjohnwu](https://github.com/topjohnwu)** | [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk) | GPL-3.0 |
| **LSPosed v1.11.0（Zygisk 版）** | **[@JingMatrix](https://github.com/JingMatrix)** & LSPosed Developers | [JingMatrix/Vector](https://github.com/JingMatrix/Vector) | GPL-3.0 |
| **Frozen 8.3.0（运行态真墓碑）** | **[@MoWei-2077](https://github.com/MoWei-2077)**（基于 **[@jark006](https://github.com/jark006)** 分支） | [MoWei-2077/FrozenVS](https://github.com/MoWei-2077/FrozenVS) \| [jark006/freezeitVS](https://github.com/jark006/freezeitVS) | GPL-3.0 |
| **RebootNya v1.9.0（开源重启工具）** | **[@daisukiKaffuChino](https://github.com/daisukiKaffuChino)** | [daisukiKaffuChino/RebootNya](https://github.com/daisukiKaffuChino/RebootNya) | Apache-2.0 |
| **FlClash v0.9.4** | **[@chen08209](https://github.com/chen08209)** | [chen08209/FlClash](https://github.com/chen08209/FlClash) | GPL-3.0 |
| **荣耀 Play `9.1.0.350` 212 字节 SELinux 内核补丁** | **[@erha-erha](https://github.com/erha-erha)** | [erha-erha/honor-play-emui9.1-350-selinux-kernel](https://github.com/erha-erha/honor-play-emui9.1-350-selinux-kernel) | 开源 |
| **姊妹机型实战指南（华为畅享 9 Plus / 麒麟 710）** | **[@erha-erha](https://github.com/erha-erha)** | [erha-erha/huawei-enjoy9plus-a14-flash-guide](https://github.com/erha-erha/huawei-enjoy9plus-a14-flash-guide) | 开源 |
