# Honor Play (`COR-AL10` / Kirin 970) — Android 14 (`LeaOS 21.0 Google`) Flashing Field Guide

**English** | [简体中文](README.zh-CN.md)

> **Target Device**: Honor Play (`COR-AL10`, device codename `HWCOR`, HiSilicon Kirin 970, `arm64-v8a`, UFS storage, `system = /dev/block/sdd62 / 2.97 GB (2,969,567,232 B)`, `userdata = /dev/block/sdd66 / 112 GB (120,586,240,000 B)`)  
> **Starting State**: Unlocked Bootloader (`verifiedbootstate=orange`), Stock EMUI `9.1.0.350(C00E440R1P2)` (`Linux 4.9.148`, VNDK 28, EROFS `/` and `/vendor`), Magisk `27.0` in `recovery_ramdisk`, and the stock `9.1.0.350` kernel with the [212-byte SELinux-unlock patch](https://github.com/erha-erha/honor-play-emui9.1-350-selinux-kernel) (boots Enforcing by default).  
> **Verified Outcome**: **Android 14** (`LeaOS 21.0` Google / LineageOS 21 pre-QPR2, `UQ1A.240205.004`, EROFS) + `SHRP-Reborn v3.2 charlotte` Recovery (Kirin 970 UFS) + stock `9.1.0.350` kernel (no custom-compiled A14 kernel needed) — booted cleanly in **90 seconds** with 112 GB `/data` mounted, plus persistent **Magisk v30.7**, **3 GiB LZ4 ZRAM**, **iOS-style runtime tombstone (`LSPosed v1.11.0 + Frozen 8.3.0`)**, **`RebootNya` soft reboot**, **Kirin 970 + Mali-G72 60Hz low-latency smoothness tuning (`honorplay_smooth`)**, **Camera Scudo crash fix (`honorplay_camera_fix`)**, and **permanent wired USB ADB self-healing (`huawei_usb_adb_fix v1.2.0`)**.

---

## Table of Contents

- [1. Verified Images, Modules & Tools](#1-verified-images-modules--tools)
- [2. Phase 1: Full Partition Backup, Stock Kernel Rescue & Stock Recovery Extraction](#2-phase-1-full-partition-backup-stock-kernel-rescue--stock-recovery-extraction)
- [3. Phase 2: Entering Fastboot & Fixing Windows 11 `HI3650` (`libwdi`) Driver Hijack](#3-phase-2-entering-fastboot--fixing-windows-11-hi3650-libwdi-driver-hijack)
- [4. Phase 3: Flashing Android 14 & SHRP (`charlotte`)](#4-phase-3-flashing-android-14--shrp-charlotte)
- [5. Phase 4: Root-Cause Analysis of the 3-Circle Boot Hang (Cross-Device EMUI 9.1 F2FS Issue)](#5-phase-4-root-cause-analysis-of-the-3-circle-boot-hang-cross-device-emui-91-f2fs-issue)
- [6. Phase 5: Proper `/data` Formatting in SHRP & First Boot Verification](#6-phase-5-proper-data-formatting-in-shrp--first-boot-verification)
- [7. Phase 6: Post-Flash Optimization, Camera Fix & Permanent Wired USB ADB](#7-phase-6-post-flash-optimization-camera-fix--permanent-wired-usb-adb)
- [8. Post-Boot Notes & Restore Path](#8-post-boot-notes--restore-path)
- [9. Troubleshooting Quick Reference](#9-troubleshooting-quick-reference)
- [10. Credits, Copyright & Upstream Attribution](#10-credits-copyright--upstream-attribution)

---

## 1. Verified Images, Modules & Tools

> **Fast Download Mirrors (GitHub Releases)**:
> - **Core ROM & Recovery Pack**: **[Releases (`v1.0-mirror`)](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/tag/v1.0-mirror)** (`LeaOS 21.0`, `SHRP charlotte`, USB driver, `SHA256SUMS.txt`).
> - **Root, ZRAM, Tombstone & Smoothness Pack (Honor Play / Kirin 970 ONLY)**: **[Releases (`v1.1-optimization`)](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/tag/v1.1-optimization)** (`honorplay_smooth`, `honorplay_zram3g`, `COR-AL10 9.1.0.350` Magisk v30.7 recovery image, plus GPLv3/Apache-2.0 upstream mirrors).
> - **Camera Scudo Fix & Permanent Wired USB ADB Pack**: **[Releases (`v1.2-camera-usb-fix`)](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/tag/v1.2-camera-usb-fix)** (`honorplay_camera_fix-v1.0.0.zip` [Kirin 970 ONLY] + `huawei_usb_adb_fix-v1.2.0.zip` [EMUI 9.1 Kirin 970/710 generic] + `SHA256SUMS.txt`).
> - **⚠️ Hardware Separation Warning**: Device-specific modules (`honorplay_smooth`, `honorplay_zram3g`, `honorplay_camera_fix`) target **Honor Play (`COR-AL10` / Kirin 970 / Mali-G72 / 6 GB RAM)** ONLY and enforce `ro.hardware == kirin970` in `customize.sh`. Only `huawei_usb_adb_fix` is a shared EMUI 9.1 ConfigFS/FunctionFS fix verified on both Kirin 970 and Kirin 710. For **Huawei Enjoy 9 Plus (Kirin 710 / Mali-G51 / 4 GB RAM)**, use the separate repo [huawei-enjoy9plus-a14-flash-guide](https://github.com/erha-erha/huawei-enjoy9plus-a14-flash-guide).

| Role | Artifact / Tool | Verified Size | Target Partition / Notes | Upstream Source & Fast Mirror |
| :--- | :--- | :--- | :--- | :--- |
| Android 14 ROM (GApps) | `LeaOS-21.0-20260118-iceows-google-pot.img.xz` → `.img` | Compressed: `1,357,554,880` B<br>Extracted: `2,197,798,912` B (~2.05 GiB) | Flash to `system` (EROFS lz4; fits inside 2.77 GiB `system` partition) | [@Iceows SourceForge](https://sourceforge.net/projects/altairfr-huawei/files/LeaOS-21.0/LeaOS-21.0-20260118-iceows-google-pot.img.xz/download) \| [v1.0 Mirror](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.0-mirror/LeaOS-21.0-20260118-iceows-google-pot.img.xz) |
| Custom Recovery (Kirin 970 UFS) | `SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip` → `recovery.img` | Zip: `45,663,147` B<br>`recovery.img`: `27,068,416` B (~25.8 MiB) | Flash to `recovery_ramdisk` (includes Iceows patched `make_f2fs 1.14.0`) | [@Iceows SourceForge](https://sourceforge.net/projects/altairfr-huawei/files/SHRP-Recovery/SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip/download) \| [v1.0 Mirror (zip)](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.0-mirror/SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip) \| [Pre-extracted `.img`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.0-mirror/SHRP-Reborn_v3.2_charlotte-recovery.img) |
| Kernel | Stock `9.1.0.350` `4.9.148` kernel (with 212-byte SELinux-unlock patch) | `25,165,824` B (24 MiB) | Kept intact on `kernel` — no custom A14 kernel needed | [@erha-erha/honor-play-emui9.1-350-selinux-kernel](https://github.com/erha-erha/honor-play-emui9.1-350-selinux-kernel) |
| Magisk Root (EMUI 9.1 `9.1.0.350`) | `Magisk-v30.7.apk` & `COR-AL10_9.1.0.350_recovery_ramdisk_magisk307.img` | APK: `11.6 MB`<br>Image: `33,554,432` B | Flash patched image to `recovery_ramdisk` (**ONLY** for `COR-AL10 9.1.0.350`, `RECOVERYMODE=true`, `PREINITDEVICE=cache`) | [@topjohnwu/Magisk](https://github.com/topjohnwu/Magisk/releases) \| [v1.1 APK](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/Magisk-v30.7.apk) \| [v1.1 `.img`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/COR-AL10_9.1.0.350_recovery_ramdisk_magisk307.img) |
| 60Hz Smoothness Module (Kirin 970) | `honorplay_smooth-v1.0.0.zip` ([source](modules/honorplay_smooth/)) | `2,568` B | Flash in Magisk Manager; fixes LeaOS HWUI/VSync lag + Kirin 970 CPU/Mali-G72 tuning | [v1.1 Release](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/honorplay_smooth-v1.0.0.zip) |
| 3 GiB LZ4 ZRAM Module (6 GB RAM) | `honorplay_zram3g-v1.0.0.zip` ([source](modules/honorplay_zram3g/)) | `1,630` B | Flash in Magisk Manager; auto-enables 3 GiB LZ4 ZRAM on every Magisk boot | [v1.1 Release](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/honorplay_zram3g-v1.0.0.zip) |
| Camera Scudo Crash Fix (Kirin 970 ONLY) | `honorplay_camera_fix-v1.0.0.zip` ([source](modules/honorplay_camera_fix/)) | `2,448` B | Flash in Magisk Manager; patches local `/odm/etc/camera/ippalgoconfig.xml` (`SmartAE switcher="0"`) to stop `libSmartAE.so` Scudo `SIGSEGV` (zero Huawei binaries bundled) | [v1.2 Release](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.2-camera-usb-fix/honorplay_camera_fix-v1.0.0.zip) |
| Permanent Wired USB ADB Fix (Kirin 970/710) | `huawei_usb_adb_fix-v1.2.0.zip` ([source](modules/huawei_usb_adb_fix/)) | `3,811` B | Flash in Magisk Manager; overrides `manufacture,adb` and runs 0% idle CPU event-driven self-healing for `FUNCTIONFS_BIND` / `EBUSY` / `-12 ENOMEM` deadlocks | [v1.2 Release](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.2-camera-usb-fix/huawei_usb_adb_fix-v1.2.0.zip) |
| LSPosed Framework (Zygisk) | `LSPosed-v1.11.0-7209-zygisk-release.zip` | `6.79 MB` | Required for Frozen System Framework Hook (Android 14 API 34) | [@JingMatrix/Vector (LSPosed)](https://github.com/JingMatrix/Vector/releases) \| [v1.1 Mirror](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/LSPosed-v1.11.0-7209-zygisk-release.zip) |
| True Runtime Tombstone | `Frozen8.3.0.zip` | `3.04 MB` | iOS-style background suspension (`GLOBAL_SIGSTOP`, works on Linux `4.9.148` + A14) | [@MoWei-2077/FrozenVS](https://github.com/MoWei-2077/FrozenVS) \| [v1.1 Mirror](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/Frozen8.3.0.zip) |
| Open-Source Reboot Tool | `RebootNya_1.9.0.apk` | `3.01 MB` | One-tap **Soft Reboot** (`setprop ctl.restart zygote`) without unplugging USB or losing Magisk | [@daisukiKaffuChino/RebootNya](https://github.com/daisukiKaffuChino/RebootNya/releases) \| [v1.1 Mirror](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/RebootNya_1.9.0.apk) |
| Proxy Client (Optional) | `FlClash-0.9.4-android-arm64-v8a.apk` | `60.86 MB` | `arm64-v8a` proxy client (whitelist in Frozen!) | [@chen08209/FlClash](https://github.com/chen08209/FlClash/releases) \| [v1.1 Mirror](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/FlClash-0.9.4-android-arm64-v8a.apk) |
| Platform Tools / USB Driver | Google `adb` / `fastboot` `37.0.1` + optional `google_usb_driver.zip` | Driver zip: `8,682,859` B | Auto-sparses raw 2.05 GiB `.img` into 5 chunks matching Huawei's `max-download-size` (450 MiB) | Android SDK Platform-Tools \| [v1.0 Driver Mirror](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.0-mirror/google_usb_driver.zip) |

### Why `iceows-google-pot.img` Works on Honor Play (`COR-AL10`)
- Iceows publishes `LeaOS 21.0` images named after his test devices (`pot` = P Smart 2019, `ane` = P20 Lite), without a separate `-cor` file for Android 14.
- Inspecting Iceows's `huawei-creator` (`android-14/run-huawei-emui9-ab-a14.sh`) and `vndk-detect` confirms:
  - All core EMUI 9.1 patches (`/splash2`, `/modem_log`, `/preavs`, Kirin graphics/audio/CPU props, `tee_auth_daemon`, Bluetooth aptX, VNDK 28/29 compatibility, 4.9 no-BPF fallbacks) are **shared identically** across models.
  - `vndk-detect` explicitly detects `kirin970` and enables Huawei overlays/camera/radio fixes.
  - Honor Play (`COR-AL10`) shares the same `hisi / hi1102` connectivity chip (`ro.connectivity.chiptype=hisi`, `ro.connectivity.sub_chiptype=hi1102`) and has NFC disabled (`ro.config.nfcdisabled=true`), so Potter's AGPS/NFC configs cause no conflict.
  - The only cosmetic side effect is that Settings → About Phone displays `POT-LX1`.
- **EROFS myth debunked on Kirin 970 EMUI 9.1.0.350**: Although `huawei-creator` Issue #6 notes that EMUI 9.1's `4.9` kernel uses an older Huawei EROFS driver (`compat=0x0` vs `mkfs.erofs 1.5`'s `compat=0x3`), direct verification inside SHRP on the `4.9.148` kernel confirmed `mount -t erofs -o ro /dev/block/by-name/system` succeeded (`rc=0`) and read compressed `/system/framework/framework.jar` with zero errors.

---

## 2. Phase 1: Full Partition Backup, Stock Kernel Rescue & Stock Recovery Extraction

Because the device was already rooted with Magisk `27.0` on EMUI `9.1.0.350`, back up every non-userdata partition **before** touching Fastboot.

### 2.1 Avoiding `adb exec-out` Corruption on Windows
- **Pitfall**: Streaming `adb exec-out "su -c 'dd if=/dev/block/by-name/<part>'"` directly to a file on Windows can corrupt binary payloads (e.g., `nvme` gained 133 extra bytes due to `su` PTY/newline mangling and failed SHA-256 verification).
- **Reliable Method**: `dd` each partition inside the phone to `/data/local/tmp/bak_<part>.img`, pull via `adb -s <SERIAL> pull`, remove the temp file, and verify both exact byte length (`blockdev --getsize64`) and SHA-256 (`sha256sum` on-device vs `Get-FileHash` on PC).
- **Multi-device safety**: Always pass `-s <SERIAL>` to every `adb` and `fastboot` command if any emulator or second device is running on the PC.
- **Expected result**: 67 partitions (all except `userdata` and `cache`, totaling ~6.73 GB) backed up. **66/67** match SHA-256 bit-for-bit, including critical unrecoverable partitions (`oeminfo`, `nvme`, `modemnvm_*`, `modem_*`, `system`, `vendor`, `product`, `recovery_ramdisk`, `kernel`). Only `splash2` mismatches because it is mounted `rw` as a live ext4 log partition during runtime (normal and non-critical).

### 2.2 Rescue Any Files Stored Inside `/data/local/tmp` Before Wiping `/data`
- Formatting `userdata` permanently wipes `/data/local/tmp/`. Check for and pull any prior backups stored there first (in this case, `/data/local/tmp/kbackup/` contained `stock_kernel_350.img`, `stock_misc_350.img`, `stock_vbmeta_350.img`, and `stock_recovery_ramdisk_magisk27.img`).

### 2.3 Extracting a Clean Stock `recovery_ramdisk` from Magisk 27.0 (Optional Safety Net)
Since Magisk on EMUI 9.1 patches `recovery_ramdisk` and preserves the original `init` inside `.backup/init.xz`, you can cleanly restore an unpatched stock recovery image on-device (read-only against a copy) using Magisk's own `magiskboot`:
```sh
mkdir -p /data/local/tmp/rec_restore && cd /data/local/tmp/rec_restore
cp /dev/block/by-name/recovery_ramdisk ./patched.img
/data/adb/magisk/magiskboot unpack patched.img
/data/adb/magisk/magiskboot cpio ramdisk.cpio restore
/data/adb/magisk/magiskboot repack patched.img stock_recovery_ramdisk.img
```
Pull `stock_recovery_ramdisk.img` to your backup directory alongside the Magisk-patched `recovery_ramdisk.img`.

---

## 3. Phase 2: Entering Fastboot & Fixing Windows 11 `HI3650` (`libwdi`) Driver Hijack

### 3.1 `adb reboot bootloader` Bounces Back to Normal EMUI
- **Symptom**: Running `adb -s <SERIAL> reboot bootloader` rebooted the phone straight back into normal EMUI instead of entering Fastboot mode.
- **Reliable Hardware Entry**:
  1. Unplug the USB cable and power off the phone completely.
  2. Hold **Volume Down** and plug in the USB cable connected to the PC until the white `FASTBOOT&RESCUE MODE` screen appears (`PHONE Unlocked`, `FRP Unlock`).

### 3.2 `fastboot devices` Empty While Device Manager Shows `HI3650` (`VID_18D1&PID_D00D`)
- **Symptom**: The phone is in Fastboot (`USB\VID_18D1&PID_D00D`, Compatible ID `USB\Class_FF&SubClass_42&Prot_03`), yet `fastboot devices` returns nothing. Device Manager shows `HI3650` under **Universal Serial Bus devices (`USBDevice`)**.
- **Root Cause**: A previously installed Zadig / `libwdi` driver (`hi3650.inf` / `oemXX.inf`) bound `VID_18D1&PID_D00D` to WinUSB with a custom random `DeviceInterfaceGUID`, missing the Google Fastboot/ADB GUID `{F72FE0D4-CBCB-407D-8814-9ED673D0DD6B}` that `fastboot.exe` enumerates.
- **Why Device Manager "Have Disk → `android_winusb.inf`" Fails**: Because `HI3650` is locked into the `USBDevice` class, Windows rejects `android_winusb.inf` (`Class = AndroidUsbDeviceClass`) with *"The folder you specified doesn't contain a compatible software driver"*.
- **Clean One-Line Fix (No Unsigned Drivers Needed)**:
  Windows 11's inbox Microsoft-signed `winusb.inf` (`Class = USBDevice`) **already embeds `{F72FE0D4-CBCB-407d-8814-9ED673D0DD6B}`** under its `ADB Device` section! Simply find and force-delete the hijacking `libwdi` INF from an **Administrator PowerShell**:
  ```powershell
  # 1. Identify the published oemXX.inf name for hi3650.inf (Provider: libwdi)
  pnputil /enum-drivers | Select-String -Context 1,5 "hi3650|libwdi"

  # 2. Force-uninstall and delete it (replace oem46.inf with your actual oemXX.inf)
  pnputil /delete-driver oem46.inf /uninstall /force
  ```
  Immediately run `fastboot devices` — the Honor Play enumerates as `<SERIAL> fastboot` right away.

---

## 4. Phase 3: Flashing Android 14 & SHRP (`charlotte`)

1. Verify the downloaded ROM archive (`LeaOS-21.0-20260118-iceows-google-pot.img.xz`, `1,357,554,880` B) and decompress with 7-Zip (CRC64 check passes; extracted `.img` is `2,197,798,912` B ≤ `2,969,567,232` B `system` partition; EROFS magic `e2e1f5e0` at offset `1024`).
2. Extract `recovery.img` (`27,068,416` B ≤ 32 MiB, `ANDROID!` header, `kernel=0` ramdisk-only) from `SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip`.
3. Flash both partitions in Fastboot:
   ```powershell
   # Verify connection & unlock state
   fastboot -s <SERIAL> oem get-bootinfo
   # Expected: (bootloader) unlocked

   # Flash LeaOS 21.0 EROFS system image (5 sparse chunks, ~67.5s)
   fastboot -s <SERIAL> flash system LeaOS-21.0-20260118-iceows-google-pot.img

   # Flash Kirin 970 SHRP-Reborn v3.2 Recovery (0.95s)
   fastboot -s <SERIAL> flash recovery_ramdisk recovery.img
   ```
   *(Do **not** flash `vbmeta` or run `fastboot -w` / `fastboot erase userdata` on Huawei EMUI 9.1.)*

---

## 5. Phase 4: Root-Cause Analysis of the 3-Circle Boot Hang (Cross-Device EMUI 9.1 F2FS Issue)

### 5.1 What Happened When Formatting via Stock EMUI 9.1 Recovery
Before flashing SHRP, we initially formatted `/data` using **stock EMUI 9.1 Recovery** ("Wipe data / factory reset" → `yes`). On reboot, the phone passed the Honor logo and rendered the **LineageOS 3-circles boot animation**, then hung past 5 minutes without ever reaching Android.

### 5.2 Direct Evidence Captured Inside SHRP (`dmesg` + `/sys/fs/pstore/pmsg-ramoops-0`)
Booting into `charlotte` SHRP (running on the phone's actual `4.9.148` kernel) allowed live mount tests and inspection of the previous boot's crash buffer:

1. **`system` (EROFS `LeaOS 21.0`) was 100% healthy**:
   ```text
   mount -t erofs -o ro /dev/block/by-name/system /tmp/t_sys  # rc=0
   erofs: read_super, device -> /dev/block/by-name/system
   sha256sum /tmp/t_sys/system/framework/framework.jar        # succeeded cleanly
   ```
2. **`userdata` (`sdd66`) failed to mount with F2FS superblock CRC mismatch**:
   ```text
   mount: '/dev/block/by-name/userdata'->'/tmp/t_data': Invalid argument
   F2FS-fs (sdd66): Invalid checksum crc(0x100b1449)
   F2FS-fs (sdd66): Can't find valid F2FS filesystem in 1th superblock
   F2FS-fs (sdd66): Invalid checksum crc(0x100b1449)
   F2FS-fs (sdd66): Can't find valid F2FS filesystem in 2th superblock
   ```
3. **`/sys/fs/pstore/pmsg-ramoops-0` confirmed the exact crash cascade**:
   ```text
   credstore main.cpp:49] Check failed: chdir(data_dir.c_str()) != -1 chdir: /data/misc/credstore: No such file or directory
   tombstoned failed to open directory: /data/tombstones: No such file or directory
   tombstoned received fatal signal 6
   ```

### 5.3 Cross-Device Root-Cause Synthesis (Kirin 710 + Kirin 970 on EMUI 9.1)
Comparing this failure with [Huawei Enjoy 9 Plus (`JKM-AL00b` / Kirin 710)](https://github.com/erha-erha/huawei-enjoy9plus-a14-flash-guide) proves this is a **universal Huawei EMUI 9.1 cross-SoC issue**:

- **Why stock EMUI 9.1 Recovery fails**: Stock Recovery formats `userdata` using Huawei's newer/proprietary F2FS superblock features (`sb_checksum` / `verity` / `quota_ino` / Huawei inline & SDP encryption flags), which fail superblock CRC verification (`Invalid checksum crc`) when mounted during GSI boot.
- **Why generic upstream `mkfs.f2fs` / unpatched TWRP also fails**: Upstream `f2fs-tools` sets `CP_NAT_BITS_FLAG` (NAT bitmap pages in checkpoint), which Huawei's EMUI 9.1 `4.9` F2FS driver rejects. Iceows's `make_f2fs` (`0001-mkfs.f2fs-Remove-NAT-Bitmap-to-support-Huawei-EMUI9-.patch`) explicitly removes `CP_NAT_BITS_FLAG` while keeping `-O encrypt` compatible with `/vendor/etc/fstab.kirin970` (`fileencryption=aes-256-xts:aes-256-cts`).
- **How Kirin 710 and Kirin 970 compare**:

| Dimension | Huawei Enjoy 9 Plus (`JKM-AL00b` / Kirin 710) | Honor Play (`COR-AL10` / Kirin 970) |
| :--- | :--- | :--- |
| **`userdata` block device** | `/dev/block/mmcblk0p70` (eMMC, ~111 GB) | `/dev/block/sdd66` (UFS, ~112 GB) |
| **Error after stock Recovery wipe** | `F2FS-fs (mmcblk0p70): Invalid checksum crc` → `credstore` crash → 3-circle hang | `F2FS-fs (sdd66): Invalid checksum crc(0x100b1449)` → `credstore` / `tombstoned` crash → 3-circle hang |
| **SHRP Recovery used** | `SHRP v3.1 potter` (`make_f2fs 1.13.0`) | `SHRP-Reborn v3.2 charlotte` (`make_f2fs 1.14.0`) |
| **ROM (`LeaOS-21.0-*-google-pot.img`)** | EROFS mounts & boots | EROFS mounts & boots |
| **Kernel requirement** | Needed Iceows A14 kernel (`Kirin710_EMUI9.1_PM` with `LOOP_CONFIGURE` backports) + F2FS fix | Booted in **90 seconds** on stock `9.1.0.350` `4.9.148` kernel (with 212-byte SELinux-unlock patch, Enforcing at boot) after F2FS fix alone |

---

## 6. Phase 5: Proper `/data` Formatting in SHRP & First Boot Verification

1. **Enter SHRP Recovery**:
   - **Unplug the USB cable first** (holding Volume Up while plugged into USB enters Huawei **eRecovery** instead of Recovery).
   - From Fastboot, hold **Volume Up + Power** continuously (~10s through reboot and the unlocked warning screen) until SHRP loads.
   - If prompted `Keep System Read Only?`, keep it read-only. Reconnect the USB cable (even if touchscreen calibration differs on `charlotte` SHRP, `adb shell` works reliably over USB).
2. **Reformat `userdata` using Iceows's `make_f2fs` and verify mount before rebooting**:
   ```sh
   # Unmount /data if mounted
   umount /data 2>/dev/null || true

   # Format userdata with Iceows patched make_f2fs (1.14.0)
   # Omit sector count so make_f2fs auto-sizes for COR-AL10's 112 GB UFS userdata
   # (Never copy another device's sector count verbatim!)
   /system/bin/make_f2fs -f -O encrypt -w 4096 /dev/block/by-name/userdata

   # Live mount verification — MUST succeed with rc=0 and show ~112G with zero CRC errors in dmesg
   mkdir -p /tmp/t_data
   mount -t f2fs /dev/block/by-name/userdata /tmp/t_data
   df -h /tmp/t_data
   dmesg | grep -iE "f2fs|sdd66|error|crc" | tail -10
   umount /tmp/t_data

   # Wipe /cache and reboot to Android 14
   mkdir -p /tmp/t_cache
   mount /dev/block/by-name/cache /tmp/t_cache 2>/dev/null || true
   rm -rf /tmp/t_cache/* /cache/* 2>/dev/null || true
   umount /tmp/t_cache 2>/dev/null || true
   sync
   reboot
   ```
   Expected kernel mount confirmation:
   ```text
   /dev/block/sdd66 112G 1.7G 111G 2% /tmp/t_data
   F2FS-fs (sdd66): F2fs successfully mounted with checkpoint version = ...
   ```
3. **First Boot Verification (`90s`)**:
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

## 7. Phase 6: Post-Flash Optimization, Camera Fix & Permanent Wired USB ADB

### 7.1 Magisk v30.7 (`recovery_ramdisk`) & EMUI 9.1 Boot / Soft-Reboot Workflow
- **Flashing Magisk v30.7**: Because EMUI 9.1 has no standalone `boot` ramdisk, Magisk patches `recovery_ramdisk` with `RECOVERYMODE=true`, `KEEPVERITY=true`, `KEEPFORCEENCRYPT=true`, and `PREINITDEVICE=cache` (this overwrites SHRP; re-flash SHRP anytime via Fastboot if needed).
  ```powershell
  # Install Magisk v30.7 Manager
  adb -s <SERIAL> install -r Magisk-v30.7.apk
  # Flash stock 9.1.0.350 recovery_ramdisk patched with Magisk v30.7 (ONLY for COR-AL10 9.1.0.350!)
  fastboot -s <SERIAL> flash recovery_ramdisk COR-AL10_9.1.0.350_recovery_ramdisk_magisk307.img
  ```
- **Exact Cold-Boot Key Timing on EMUI 9.1** (when booting from powered-off state):
  1. **Unplug the USB cable** first (holding Volume Up while USB is connected enters Huawei eRecovery).
  2. Hold **Volume Up + Power** continuously until the unlocked warning screen appears (`Your device has been unlocked...`).
  3. You may release Power, but **keep holding Volume Up** until **`Your device is booting now...`** appears (~5 seconds) — **release Volume Up immediately at that moment**. Releasing too early falls back to `enter_recovery=0` (unrooted normal OS); holding too long enters stock Huawei Recovery (⚠️ **never** tap Factory Reset there!).
  4. On first Magisk boot, open Magisk Manager to complete the one-time environment setup (populates `/data/adb/magisk`) and enable **Zygisk**.
- **Daily Zero-Button Reboots via [`RebootNya v1.9.0`](https://github.com/daisukiKaffuChino/RebootNya)**:
  - Huawei EMUI 9.1's closed-source Bootloader intercepts wired `reboot recovery` into eRecovery/power-off.
  - For 99% of daily restarts (activating LSPosed modules, refreshing system tweaks), tap **`RebootNya` → Soft Reboot** (`setprop ctl.restart zygote`). Verified to reload `system_server` + LSPosed hooks in **6.5 seconds** with **zero cable unplugging, zero hardware buttons**, while preserving `Magisk v30.7` and `3 GiB ZRAM`.

### 7.2 Persistent 3 GiB LZ4 ZRAM (`honorplay_zram3g`) vs Disk Swap
- **Why ZRAM beats disk swap on Honor Play**: Honor Play's 128 GB UFS 2.1 (`KLUDG4U1EA-B0C1`) is fast for file storage, but disk-based swap still suffers flash wear and millisecond I/O spikes. **LZ4 ZRAM** compresses cold memory pages entirely inside RAM at multi-GB/s with zero flash wear.
- Flash [`honorplay_zram3g-v1.0.0.zip`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/honorplay_zram3g-v1.0.0.zip) ([source](modules/honorplay_zram3g/)) in Magisk Manager to auto-enable `3 GiB` (`3,221,225,472` B) LZ4 ZRAM (`swapon -p 100`, `vm.page-cluster=0`, `vm.swappiness=80`) on every Magisk boot.

### 7.3 True iOS-Style Runtime Tombstone (`LSPosed v1.11.0 + Frozen 8.3.0`) on Android 14 + Linux 4.9
- **Runtime Tombstone vs "IceBox/Hail"**: Unlike app disablers that `pm disable` and kill apps (forcing cold restarts), a true runtime tombstone suspends background app processes in RAM at **0% CPU** and **instantaneously resumes the exact same PID** when tapped.
- **Why `Frozen 8.3.0` (`MoWei-2077/FrozenVS`)**:
  - Linux `4.9.148` lacks **cgroup v2 `cgroup.freeze`** (so `Cirno` and Android 14 native `cached_apps_freezer` cannot freeze via cgroup v2, and upstream `freezeit v3.0.0` blocks kernels `< 5.10`).
  - `Frozen 8.3.0` removes the 5.10 kernel gate, builds for `arm64-v8a` + Android 14 (`targetSdk=34`), and automatically uses **`GLOBAL_SIGSTOP`** (`SIGSTOP`/`SIGCONT`, avoiding Linux 4.9 cgroup v1 missing-`freezer.killable` `lmkd` hangs) paired with an **LSPosed System Framework Hook** to suppress ANR crashes and thaw immediately on resume.
- **Deployment & Whitelist**:
  1. Enable **Zygisk** in Magisk, flash `LSPosed-v1.11.0-7209-zygisk-release.zip` and `Frozen8.3.0.zip`.
  2. Reboot (or soft-reboot), open **LSPosed Manager → Modules → Frozen**, turn on **Enable module** and verify **System Framework (`system`)** is checked, then tap **RebootNya → Soft Reboot** (6.5s).
  3. **Critical Whitelist (`自由后台` / `40 1` in `/data/adb/modules/Frozen/appcfg.txt`)**: Always whitelist your proxy VPN (`com.follow.clash`), IME (`com.bytedance.android.doubaoime`), `com.google.android.gms`, `com.google.android.gsf`, `com.topjohnwu.magisk`, and real-time messaging apps (`com.tencent.mm`, etc.).
- **Verified Live Behavior**: Background Chrome, YouTube, Gmail, Drive, and Translate all enter kernel `State: T (stopped)` / `wchan: do_signal_stop` (0% CPU). Tapping YouTube resumes the **exact same PID** instantaneously (`S (sleeping)`), then auto-suspends again after switching away.

### 7.4 60Hz Smoothness & Low-Latency Tuning (`honorplay_smooth` — Kirin 970 ONLY)
- **Hardware Refresh Rate Fact**: Honor Play's LCD panel physical maximum is **`60.00 Hz`** (`supportedModes [{fps=60.000004}]`). Sluggish scrolling and laggy touch feel were **not** caused by 60Hz itself, but by 4 verified software bottlenecks fixed in [`honorplay_smooth-v1.0.0.zip`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.1-optimization/honorplay_smooth-v1.0.0.zip) ([source](modules/honorplay_smooth/)):
  1. **Broken Legacy Graphics Props in `LeaOS 21.0` `/system/build.prop`**: `hwui.disable_vsync=true`, `debug.hwui.use_buffer_age=false`, `debug.egl.profiler=1`, and `debug.hwui.profile=true` caused `5.4–8.0 ms` per-frame `DequeueBuffer` stalls, 3-frame (`48.2 ms`) display latency, and forced full-screen redraws. Fixed cleanly via Magisk `system.prop` **while deliberately keeping Huawei EMUI 9.1 HWC 2.2's required `debug.sf.disable_backpressure=1` and `debug.sf.latch_unsignaled=1`** (disabling those two causes Mali-G72 dual-layer Launcher3 fence stalls down to 14.5 FPS!).
  2. **Kirin 970 `interactive` Governor 118ms Big-Core Lag**: Tuned `policy0` (A53) & `policy4` (A73) to `12 ms` polling (`timer_rate`), `10–15 ms` big-core ramp delay, `io_is_busy=1`, `fast_ramp_down=0`.
  3. **Mali-G72 GPU Sticking at `237 MHz`**: Raised wake floor from `237 MHz` to mid-step **`415 MHz`** (out of `767 MHz`; still power-gates when idle, measured GPU temp `27℃`) + `scene=1` (`550 MHz` hispeed).
  4. **Window Blurs & Runaway Debug Logger**: Disabled Android 14 GPU blurs (`disable_window_blurs=1`), set `0.5x` animation scales, and stopped `dump-logs` if active.

| Measured Metric (`dumpsys gfxinfo`, 60Hz) | Before Tuning | After `honorplay_smooth` |
| :--- | :--- | :--- |
| Settings `DequeueBufferDuration` (per frame) | `5.4–8.0 ms` | **`0.04 ms`** (~150× faster) |
| Settings Median Frame Time / Jank | `21 ms` / Legacy `98.6%` | **`15 ms` / `0.00%` (Legacy `9.8%`)** |
| Launcher3 Home Swipe Median / Missed VSync | `25–69 ms` / Frequent drops | **`16 ms` / `0` Missed VSync** |

### 7.5 Camera Scudo Crash Fix (`honorplay_camera_fix` — Kirin 970 ONLY) & Full Hardware Audit
- **Symptom**: On Honor Play (`COR-AL10`) running `LeaOS 21.0` (Android 14), LineageOS **Aperture** fails to connect or shows a black viewfinder, while **GCam Go** (`com.google.android.apps.cameralite`) displays a frozen slideshow (~1 frame every few seconds).
- **Verified Root Cause (Tombstones + `/vendor/lib64/libSmartAE.so` Disassembly)**:
  - `initSmartAEAlgo` (`+0x154ec`) allocates `0x77a00` bytes (`489,984 B`), while `SmartAE::Init` (`+0x13610`) executes `str wzr, [x20, #0xa00]` at `this + 0x77a00` — a **4-byte heap buffer overflow**.
  - On stock EMUI 9.1 (`jemalloc`), `0x77a00` rounded up to a `512 KiB` (`0x80000`) size class, silently absorbing the out-of-bounds write.
  - On Android 14 **Scudo**'s secondary allocator, the buffer is right-aligned against a `PROT_NONE` guard page, causing an immediate `SIGSEGV (SEGV_ACCERR)` inside `CameraDaemon` on frame 1 and triggering an endless ~5-second crash-and-respawn loop.
- **Why Disabling `SmartAE` Beats Binary-Patching `libSmartAE.so`**:
  - A/B testing an 8-byte binary patch (`0x77a00 → 0x80000`) stopped the crash, but `IppAlgoSmartAE` still spammed `doSmartAEAlgo() failed to getSceneMode` every 50 ms under AOSP because Huawei's proprietary scene-mode metadata is absent in LineageOS.
  - [`honorplay_camera_fix-v1.0.0.zip`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.2-camera-usb-fix/honorplay_camera_fix-v1.0.0.zip) ([source](modules/honorplay_camera_fix/)) instead sets `<IppAlgo name="SmartAE" switcher="0"` in a locally generated copy of the device's own `/odm/etc/camera/ippalgoconfig.xml` and bind-mounts it in `post-fs-data.sh` (with `service.sh` fallback and `u:object_r:vendor_configs_file:s0` SELinux context preserved, because `/odm` is a standalone EROFS partition with no `/system/odm` symlink). Result: **zero crashes, zero log spam, ~512 KiB saved per session, and zero Huawei proprietary binaries/XMLs redistributed**.
- **Live Camera & Full Hardware Audit (`COR-AL10` / Kirin 970 on `LeaOS 21.0` + Stock `9.1.0.350` Kernel, Enforcing)**:

| Subsystem | Live Verification Result | Notes |
| :--- | :--- | :--- |
| **SoC / RAM / UFS** | Working | Kirin 970 (`4×A53 + 4×A73`), 6 GB RAM + 3 GiB LZ4 ZRAM, 128 GB UFS 2.1 |
| **Display / Touch / Backlight** | Working | 60.00 Hz LCD, smooth brightness, tuned via `honorplay_smooth` |
| **Rear & Front Cameras + Torch** | Working | Aperture & GCam Go live preview, photo capture (2.4–7.6 MB), rear/front HW H.264 video (`vide`+`soun`), portrait, night mode, torch (`0→128→0`); **0 crashes / 0 SELinux AVC denials** with `honorplay_camera_fix-v1.0.0.zip` |
| **HW Video Codecs** | Working | `OMX.hisi.video.decoder/encoder` (AVC / HEVC) active |
| **Audio / Mic / 3.5 mm Jack** | Working | `HI6403` speaker, earpiece, mic, 3.5 mm jack verified |
| **Wi-Fi (2.4/5 GHz) & Bluetooth** | Working | `hi1102` 5 GHz Wi-Fi verified (~292 Mbps link, 0% packet loss); BT A2DP / HFP / BLE ready |
| **Cellular / GNSS / Fingerprint** | Working | Dual-SIM Balong baseband (`21C20B369S016C000`) & RIL HAL ready (reboot once after inserting SIM; no hot-plug), GNSS HAL ready, `Fingerprint21` HAL ready |
| **Sensors / Vibrator / RGB LED / USB** | Working | `lsm6ds3-c` accel/gyro, `akm09918` mag, `ltr578` light/proximity, hall & step sensors, vibrator, RGB notification LED, charging & wired USB ADB (protected by `huawei_usb_adb_fix-v1.2.0.zip`) |
| **NFC / IR Blaster** | N/A | Hardware absent on `COR-AL10` (`ro.config.nfcdisabled=true`) |

### 7.6 Permanent Wired USB ADB Self-Healing Fix (`huawei_usb_adb_fix v1.2.0`)
- **Symptom**: After unplugging/replugging, deep sleep, or switching between two Huawei/Honor EMUI 9.1 phones on the same PC, wired USB debugging vanishes completely — Windows Device Manager shows zero `VID_12D1` devices and the phone only charges (even though Wireless Debugging still works). This is **NOT** a Windows multi-device driver conflict.
- **Verified 3-Layer Phone-Side Root Cause (Shared on Both Kirin 970 & Kirin 710 EMUI 9.1 + `LeaOS 21.0`)**:
  1. **Invalid Vendor Default**: `/vendor/default.prop` hardcodes `persist.sys.usb.config=manufacture,adb`, which has no matching `on property:` rule in LeaOS `init.usb.configfs.rc` or `init.hisi.usb.rc`.
  2. **Android 14 `adbd` ↔ Linux 4.9 `f_fs.c` `FUNCTIONFS_BIND` / `EBUSY` Deadlock**: Android 14 APEX `/apex/com.android.adbd/bin/adbd` hardcodes a 1-second `FUNCTIONFS_BIND` timeout (`timed out while waiting for FUNCTIONFS_BIND, trying again`, no disable prop). When unplug/replug or sleep causes `adbd` to reopen `ep0` while `/config/usb_gadget/g1/UDC` is still `ff100000.dwc3`, `init`'s UDC rewrite fails with `EBUSY` and Linux 4.9 `f_fs.c` never re-emits `FUNCTIONFS_BIND`, locking `adbd` into an infinite 1-second loop that drops USB D+ pull-up.
  3. **Poisoned `ffs.adb` → `-12 ENOMEM`**: Once looped, Linux 4.9's `ffs.adb` ConfigFS instance fails even standard `sys.usb.config none → adb` with `configfs-gadget ff100000.dwc3: failed to start g1: -12 (Out of memory)` until `/dev/usb-ffs/adb` is unmounted, `ffs.adb` is removed & recreated, and `functionfs` is remounted.
- **Permanent Fix ([`huawei_usb_adb_fix-v1.2.0.zip`](https://github.com/erha-erha/honor-play-a14-flash-guide/releases/download/v1.2-camera-usb-fix/huawei_usb_adb_fix-v1.2.0.zip) / [source](modules/huawei_usb_adb_fix/))**:
  - `system.prop` overrides `persist.sys.usb.config=adb`.
  - `usb_adb_guard.sh` runs a **0% idle CPU** event-driven watcher (`logcat -b main -T 1 -v epoch adbd:W '*:S'`), filters stale log lines by epoch timestamp, **skips recovery whenever UDC is already `configured`** (zero disruption to active transfers), checks `/proc/mounts` directly (never bare `mount`, which spins at 99% CPU on Magisk's mount table), cleanly tears down and rebuilds `ffs.adb`, and restores the user's active USB mode (`adb`, `mtp,adb`, etc.).
  - **Live Verified on Both Devices**: Confirmed 0% idle CPU and safe guard-skip when healthy on Honor Play, and confirmed automatic end-to-end recovery (~12 seconds from live broken `FUNCTIONFS_BIND`/`EBUSY` deadlock to automatic Windows `USB\VID_12D1&PID_103A` re-enumeration) on Enjoy 9 Plus.

---

## 8. Post-Boot Notes & Restore Path

- **Offline SetupWizard & Play Store / SIM Hot-Plug Tips**:
  - `LeaOS 21.0` enables `WITH_ADB_INSECURE=true`, so wired ADB works right after first boot.
  - If Google SetupWizard hangs on *"Getting your phone ready..."* in a restricted network, skip Wi-Fi and finish SetupWizard offline, then sideload your proxy tool via `adb install`.
  - For Play Store "Install" button freeze during initial self-update (`adb shell am force-stop com.android.vending`) and EMUI 9.1 Balong baseband SIM hot-plug behavior (reboot once after inserting a SIM card), see Phase 4 of [huawei-enjoy9plus-a14-flash-guide](https://github.com/erha-erha/huawei-enjoy9plus-a14-flash-guide#5-phase-4-first-boot-proxy-setup-play-store-freeze--sim-card-hot-plug-fix).
- **Returning to Stock EMUI `9.1.0.350`**:
  - Flash back your backed-up `system.img` and `stock_recovery_ramdisk.img` (plus `stock_kernel_350.img` if desired) via Fastboot, then Factory Reset in stock Recovery.
  - **Never** `fastboot flash` `oeminfo` or `nvme` — those partitions must only be restored via `dd` from a rooted shell if baseband/IMEI recovery is ever needed.

---

## 9. Troubleshooting Quick Reference

| Symptom / Error | Verified Root Cause | Solution |
| :--- | :--- | :--- |
| `adb exec-out su -c dd` backup fails SHA-256 on Windows | `su` PTY/newline conversion corrupts binary stream | `dd` to `/data/local/tmp/bak_<part>.img`, `adb -s <SERIAL> pull`, then verify SHA-256 |
| `splash2.img` SHA-256 always mismatches during backup | `/splash2` is mounted `rw` as a live ext4 log partition | Normal and expected; ignore mismatch |
| `adb reboot bootloader` reboots into normal EMUI | EMUI / Magisk `recovery_ramdisk` ignores soft bootloader reboot flag | Unplug USB, power off, hold **Volume Down** while plugging USB into PC |
| `fastboot devices` empty; Device Manager shows `HI3650` | Prior Zadig/`libwdi` INF (`hi3650.inf`) hijacks `VID_18D1&PID_D00D` without `{F72FE0D4-...}` GUID and locks `USBDevice` class | Admin PowerShell: `pnputil /delete-driver oemXX.inf /uninstall /force` so Windows falls back to inbox `winusb.inf` |
| Holding Volume Up + Power enters eRecovery instead of SHRP / Magisk | USB cable was still plugged in (or Vol Up released too early/late) | **Unplug USB first**; for Magisk release Vol Up the instant `Your device is booting now...` appears; for daily module reloads use **RebootNya → Soft Reboot** |
| Stuck on LineageOS 3-circle boot animation (> 5 min) | Stock EMUI 9.1 Recovery F2FS format triggers `F2FS-fs (sdd66): Invalid checksum crc` → `/data` unmounted → `credstore` crash loop | Flash `SHRP-Reborn v3.2 charlotte`, run `/system/bin/make_f2fs -f -O encrypt -w 4096 /dev/block/by-name/userdata`, verify `mount -t f2fs`, wipe `/cache`, reboot |
| SetupWizard stuck on *"Getting your phone ready..."* | Restricted network blocks Google check-in | Skip Wi-Fi to finish offline, sideload proxy via wired ADB, then sign in |
| Scrolling feels laggy / high touch latency on 60Hz `LeaOS 21.0` | LeaOS `/system/build.prop` sets `hwui.disable_vsync=true`, `use_buffer_age=false`, `egl.profiler=1`, plus conservative Kirin 970 CPU/GPU clocks | Flash `honorplay_smooth-v1.0.0.zip` in Magisk (keeps Huawei HWC 2.2 `disable_backpressure=1` & `latch_unsignaled=1`) |
| `SurfaceFlinger` crash loop if `debug.sf.use_phase_offsets_as_durations=1` is set | Conflicts with `ro.surface_flinger.vsync_event_phase_offset_ns` in Android 14 `WorkDuration` | Never set `debug.sf.use_phase_offsets_as_durations=1` on LeaOS 21.0 |
| Aperture black screen / GCam Go slideshow (~1 FPS) on `COR-AL10` | `libSmartAE.so` `SmartAE::Init +0x77a00` 4-byte heap overflow hits Android 14 Scudo guard page (`SIGSEGV`), crash-looping `CameraDaemon` every ~5s | Flash `honorplay_camera_fix-v1.0.0.zip` in Magisk (Kirin 970 ONLY; disables `SmartAE` in local `/odm/etc/camera/ippalgoconfig.xml`) |
| Wired USB debugging vanishes (charges only; PC sees zero `VID_12D1` devices) | `/vendor/default.prop` `manufacture,adb` + Android 14 `adbd` ↔ Linux 4.9 `FUNCTIONFS_BIND` / `EBUSY` / `ffs.adb -12 ENOMEM` deadlock (not a Windows driver conflict) | Flash `huawei_usb_adb_fix-v1.2.0.zip` in Magisk for permanent 0% CPU self-healing |

---

## 10. Credits, Copyright & Upstream Attribution

All third-party open-source files mirrored in GitHub Releases are **unmodified official upstream builds** provided strictly for community download convenience with full credit to their original authors and licenses. Proprietary apps (e.g., Google Play apps, input methods) are never mirrored here.

| Project / Component | Original Author(s) | Upstream Repository / Link | License |
| :--- | :--- | :--- | :--- |
| **LeaOS 21.0 (Android 14 GSI)** & **EMUI 9 F2FS `make_f2fs` Patch** | **[@Iceows](https://github.com/Iceows)** (AltairFR) | [Iceows/huawei-creator](https://github.com/Iceows/huawei-creator) \| [SourceForge](https://sourceforge.net/projects/altairfr-huawei/) | Open Source (LineageOS / Apache-2.0 / GPL) |
| **SHRP-Reborn v3.2** | **Team SHRP** & **[@Iceows](https://github.com/Iceows)** | [SHRP-Reborn](https://github.com/SHRP-Reborn) \| [SourceForge](https://sourceforge.net/projects/altairfr-huawei/files/SHRP-Recovery/) | GPL-3.0 |
| **Magisk v30.7** | **[@topjohnwu](https://github.com/topjohnwu)** | [topjohnwu/Magisk](https://github.com/topjohnwu/Magisk) | GPL-3.0 |
| **LSPosed v1.11.0 (Zygisk)** | **[@JingMatrix](https://github.com/JingMatrix)** & LSPosed Developers | [JingMatrix/Vector](https://github.com/JingMatrix/Vector) | GPL-3.0 |
| **Frozen 8.3.0 (Runtime Tombstone)** | **[@MoWei-2077](https://github.com/MoWei-2077)** (forked from **[@jark006](https://github.com/jark006)**) | [MoWei-2077/FrozenVS](https://github.com/MoWei-2077/FrozenVS) \| [jark006/freezeitVS](https://github.com/jark006/freezeitVS) | GPL-3.0 |
| **RebootNya v1.9.0** | **[@daisukiKaffuChino](https://github.com/daisukiKaffuChino)** | [daisukiKaffuChino/RebootNya](https://github.com/daisukiKaffuChino/RebootNya) | Apache-2.0 |
| **FlClash v0.9.4** | **[@chen08209](https://github.com/chen08209)** | [chen08209/FlClash](https://github.com/chen08209/FlClash) | GPL-3.0 |
| **Honor Play `9.1.0.350` 212-byte SELinux Kernel Patch** | **[@erha-erha](https://github.com/erha-erha)** | [erha-erha/honor-play-emui9.1-350-selinux-kernel](https://github.com/erha-erha/honor-play-emui9.1-350-selinux-kernel) | Open Source |
| **Sibling Guide (Huawei Enjoy 9 Plus / Kirin 710)** | **[@erha-erha](https://github.com/erha-erha)** | [erha-erha/huawei-enjoy9plus-a14-flash-guide](https://github.com/erha-erha/huawei-enjoy9plus-a14-flash-guide) | Open Source |
