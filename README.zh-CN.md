# 荣耀 Play（`COR-AL10` / Kirin 970）刷入 Android 14（`LeaOS 21.0 Google`）实战经验总结

[English](README.md) | **简体中文**

> **目标设备**：荣耀 Play 国行高配版（型号 `COR-AL10`，设备代号 `HWCOR`，SoC：海思麒麟 970，`arm64-v8a`，UFS 存储，`system = /dev/block/sdd62 / 2.97 GB (2,969,567,232 B)`，`userdata = /dev/block/sdd66 / 112 GB (120,586,240,000 B)`）  
> **起始状态**：Bootloader 已解锁（`verifiedbootstate=orange`），原厂 EMUI `9.1.0.350(C00E440R1P2)`（`Linux 4.9.148`，VNDK 28，`/` 与 `/vendor` 均为 EROFS），`recovery_ramdisk` 内已刷 Magisk `27.0`，`kernel` 为带 [212 字节 SELinux 解锁补丁](https://github.com/erha-erha/honor-play-emui9.1-350-selinux-kernel) 的原厂 `9.1.0.350` 内核（开机默认 Enforcing）。  
> **最终成果**：成功刷入 **Android 14**（`LeaOS 21.0` Google 版 / LineageOS 21 pre-QPR2，`UQ1A.240205.004`，EROFS）+ 麒麟 970 同平台 `SHRP-Reborn v3.2 charlotte` Recovery + 保留原厂 `9.1.0.350` 内核（无需另编 A14 内核）—— **90 秒直接点亮进桌面**，`/data` 112 GB 挂载正常，有线 ADB 开机即用。

---

## 目录

- [1. 实测可用软件与镜像清单](#1-实测可用软件与镜像清单)
- [2. 阶段一：全分区备份、抢救原厂内核与还原纯净 Recovery](#2-阶段一全分区备份抢救原厂内核与还原纯净-recovery)
- [3. 阶段二：进 Fastboot 与修复 Windows 11 `HI3650`（`libwdi`）驱动占坑](#3-阶段二进-fastboot-与修复-windows-11-hi3650libwdi驱动占坑)
- [4. 阶段三：Fastboot 刷入 Android 14 与 `charlotte` 版 SHRP](#4-阶段三fastboot-刷入-android-14-与-charlotte-版-shrp)
- [5. 阶段四：核心复盘——为什么卡在 LineageOS 三个转圈（EMUI 9.1 跨机型 F2FS 通病）](#5-阶段四核心复盘为什么卡在-lineageos-三个转圈emui-91-跨机型-f2fs-通病)
- [6. 阶段五：在 SHRP 内正确重格 `/data` 与 90 秒开机验证](#6-阶段五在-shrp-内正确重格-data-与-90-秒开机验证)
- [7. 开机后续事项与救砖回退方案](#7-开机后续事项与救砖回退方案)
- [8. 踩坑速查表](#8-踩坑速查表)

---

## 1. 实测可用软件与镜像清单

| 用途 | 文件 / 工具 | 实测大小 | 目标分区 / 说明 | 公开来源 |
| :--- | :--- | :--- | :--- | :--- |
| Android 14 ROM（带 GApps） | `LeaOS-21.0-20260118-iceows-google-pot.img.xz` → `.img` | 压缩包：`1,357,554,880` B<br>解压后：`2,197,798,912` B（~2.05 GiB） | 刷入 `system`（EROFS lz4，轻松塞进 2.77 GiB 的 `system` 分区，余量约 770 MB） | [SourceForge: altairfr-huawei / LeaOS-21.0](https://sourceforge.net/projects/altairfr-huawei/files/LeaOS-21.0/LeaOS-21.0-20260118-iceows-google-pot.img.xz/download) |
| 第三方 Recovery（麒麟 970 UFS） | `SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip` → `recovery.img` | 压缩包：`45,663,147` B<br>`recovery.img`：`27,068,416` B（~25.8 MiB） | 刷入 `recovery_ramdisk`（32 MiB 分区，内置 Iceows 补丁版 `mkfs.f2fs Ver Iceows (Huawei EMUI9): 1.14.0`） | [SourceForge: altairfr-huawei / SHRP-Recovery](https://sourceforge.net/projects/altairfr-huawei/files/SHRP-Recovery/SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip/download) |
| 内核 | 原厂 `9.1.0.350` `4.9.148` 内核（带 212 字节 SELinux 解锁补丁） | `25,165,824` B（24 MiB） | 保持原样不重刷，无需另行编译 A14 内核 | [erha-erha/honor-play-emui9.1-350-selinux-kernel](https://github.com/erha-erha/honor-play-emui9.1-350-selinux-kernel) |
| 刷机工具 | Google `adb` / `fastboot` `37.0.1` | — | 自动将 2.05 GiB 原始镜像切分为 5 个 sparse 分片匹配华为 `max-download-size`（450 MiB） | Android SDK Platform-Tools |

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

## 7. 开机后续事项与救砖回退方案

- **国内首次初始化、Play 商店与 SIM 卡热插拔注意事项**：
  - `LeaOS 21.0` 默认开启 `WITH_ADB_INSECURE=true`，开机后有线 ADB 直接可用。
  - 若国内无外网导致 Google 开机向导卡在“正在准备我的设备”，先**离线跳过 Wi-Fi** 进桌面，再用 `adb install` 装代理软件后登录 Google。
  - 若遇 Play 商店首次后台自更新时点“安装”无反应（`adb shell am force-stop com.android.vending`）或 EMUI 9.1 巴龙基带热插拔 SIM 卡无信号（插好卡重启一次手机），可参考 [huawei-enjoy9plus-a14-flash-guide 阶段四](https://github.com/erha-erha/huawei-enjoy9plus-a14-flash-guide/blob/main/README.zh-CN.md#5-%E9%98%B6%E6%AE%B5%E5%9B%9B%E5%9B%BD%E5%86%85%E6%97%A0%E5%A4%96%E7%BD%91%E5%88%9D%E5%A7%8B%E5%8C%96%E4%BB%A3%E7%90%86%E9%85%8D%E7%BD%AEgoogle-%E5%A5%97%E4%BB%B6%E4%B8%8E-sim-%E5%8D%A1%E6%8E%92%E5%9D%91)。
- **重新获取 Magisk Root（可选）**：
  - 建议先验证完日常通话、Wi-Fi、相机稳定后再考虑重刷 Magisk；注意 EMUI 9.1 下 Magisk 与 SHRP 共用 `recovery_ramdisk` 分区，互相覆盖。
- **随时退回原厂 EMUI `9.1.0.350`**：
  - 在 Fastboot 下刷回之前备份的 `system.img`、`stock_recovery_ramdisk.img`（及按需刷回 `stock_kernel_350.img`），再进原厂 Recovery 恢复出厂设置即可。
  - **严禁**用 `fastboot flash` 直接刷写 `oeminfo` / `nvme`，此类基带与机型分区仅在确需救砖时由 root 下 `dd` 慎重恢复。

---

## 8. 踩坑速查表

| 现象 / 报错 | 实际根因 | 解决方案 |
| :--- | :--- | :--- |
| Windows 下 `adb exec-out su -c dd` 备份 SHA-256 不一致 | `su` 标准输出换行/PTY 处理污染二进制流 | 先在手机端 `dd` 到 `/data/local/tmp`，再 `adb -s <序列号> pull` 后核对 SHA-256 |
| 备份时仅 `splash2.img` SHA-256 校验失败 | `/splash2` 为系统运行时 `rw` 挂载的实时日志分区 | 正常现象，忽略即可 |
| `adb reboot bootloader` 直接重启回正常 EMUI | EMUI / Magisk `recovery_ramdisk` 忽略软件重启到 bootloader 参数 | 拔线关机后，**按住音量下键不放插数据线**手动进 Fastboot |
| `fastboot devices` 为空、设备管理器显示 `HI3650` | 之前 Zadig/`libwdi` 装的 `hi3650.inf` 占用 `VID_18D1&PID_D00D`，缺 `{F72FE0D4-...}` GUID 且锁死 `USBDevice` 分类 | 管理员 PowerShell 执行 `pnputil /delete-driver oemXX.inf /uninstall /force`，回退到 Win11 自带 `winusb.inf` |
| 按音量上 + 电源进了 eRecovery 而非 SHRP | 按组合键时没拔掉 USB 数据线 | **先拔线**，长按音量上 + 电源进 SHRP 后再重新插线 |
| 刷完 A14 卡在 LineageOS 三个转圈超 5 分钟 | EMUI 9.1 原厂 Recovery 格出的 F2FS 触发 `F2FS-fs (sdd66): Invalid checksum crc` → `/data` 未挂载 → `credstore` 无限崩溃 | 刷 `SHRP-Reborn v3.2 charlotte`，执行 `/system/bin/make_f2fs -f -O encrypt -w 4096 /dev/block/by-name/userdata` 并实测 `mount -t f2fs` 后清 `/cache` 重启 |
| 首次开机向导卡在“正在准备我的设备” | 国内无外网导致 Google 联网检查超时 | 离线跳过 Wi-Fi 进桌面，有线 ADB 装代理后再登录 Google |
