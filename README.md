# Honor Play (`COR-AL10` / Kirin 970) — Android 14 (`LeaOS 21.0 Google`) Flashing Field Guide

**English** | [简体中文](README.zh-CN.md)

> **Target Device**: Honor Play (`COR-AL10`, device codename `HWCOR`, HiSilicon Kirin 970, `arm64-v8a`, UFS storage, `system = /dev/block/sdd62 / 2.97 GB (2,969,567,232 B)`, `userdata = /dev/block/sdd66 / 112 GB (120,586,240,000 B)`)  
> **Starting State**: Unlocked Bootloader (`verifiedbootstate=orange`), Stock EMUI `9.1.0.350(C00E440R1P2)` (`Linux 4.9.148`, VNDK 28, EROFS `/` and `/vendor`), Magisk `27.0` in `recovery_ramdisk`, and the stock `9.1.0.350` kernel with the [212-byte SELinux-unlock patch](https://github.com/erha-erha/honor-play-emui9.1-350-selinux-kernel) (boots Enforcing by default).  
> **Verified Outcome**: **Android 14** (`LeaOS 21.0` Google / LineageOS 21 pre-QPR2, `UQ1A.240205.004`, EROFS) + `SHRP-Reborn v3.2 charlotte` Recovery (Kirin 970 UFS) + stock `9.1.0.350` kernel (no custom-compiled A14 kernel needed) — booted cleanly in **90 seconds** with 112 GB `/data` mounted and wired ADB online immediately.

---

## Table of Contents

- [1. Verified Images & Tools](#1-verified-images--tools)
- [2. Phase 1: Full Partition Backup, Stock Kernel Rescue & Stock Recovery Extraction](#2-phase-1-full-partition-backup-stock-kernel-rescue--stock-recovery-extraction)
- [3. Phase 2: Entering Fastboot & Fixing Windows 11 `HI3650` (`libwdi`) Driver Hijack](#3-phase-2-entering-fastboot--fixing-windows-11-hi3650-libwdi-driver-hijack)
- [4. Phase 3: Flashing Android 14 & SHRP (`charlotte`)](#4-phase-3-flashing-android-14--shrp-charlotte)
- [5. Phase 4: Root-Cause Analysis of the 3-Circle Boot Hang (Cross-Device EMUI 9.1 F2FS Issue)](#5-phase-4-root-cause-analysis-of-the-3-circle-boot-hang-cross-device-emui-91-f2fs-issue)
- [6. Phase 5: Proper `/data` Formatting in SHRP & First Boot Verification](#6-phase-5-proper-data-formatting-in-shrp--first-boot-verification)
- [7. Post-Boot Notes & Restore Path](#7-post-boot-notes--restore-path)
- [8. Troubleshooting Quick Reference](#8-troubleshooting-quick-reference)

---

## 1. Verified Images & Tools

| Role | Artifact / Tool | Verified Size | Target Partition / Notes | Public Source |
| :--- | :--- | :--- | :--- | :--- |
| Android 14 ROM (GApps) | `LeaOS-21.0-20260118-iceows-google-pot.img.xz` → `.img` | Compressed: `1,357,554,880` B<br>Extracted: `2,197,798,912` B (~2.05 GiB) | Flash to `system` (EROFS lz4; easily fits inside 2.77 GiB `system` partition with ~770 MB spare) | [SourceForge: altairfr-huawei / LeaOS-21.0](https://sourceforge.net/projects/altairfr-huawei/files/LeaOS-21.0/LeaOS-21.0-20260118-iceows-google-pot.img.xz/download) |
| Custom Recovery (Kirin 970 UFS) | `SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip` → `recovery.img` | Zip: `45,663,147` B<br>`recovery.img`: `27,068,416` B (~25.8 MiB) | Flash to `recovery_ramdisk` (32 MiB partition; includes Iceows patched `mkfs.f2fs Ver Iceows (Huawei EMUI9): 1.14.0`) | [SourceForge: altairfr-huawei / SHRP-Recovery](https://sourceforge.net/projects/altairfr-huawei/files/SHRP-Recovery/SHRP-Reborn_v3.2_Stable-Unofficial_charlotte-04.02.26.zip/download) |
| Kernel | Stock `9.1.0.350` `4.9.148` kernel (with 212-byte SELinux-unlock patch) | `25,165,824` B (24 MiB) | Kept intact on `kernel` — no custom A14 kernel compilation required | [erha-erha/honor-play-emui9.1-350-selinux-kernel](https://github.com/erha-erha/honor-play-emui9.1-350-selinux-kernel) |
| Platform Tools | Google `adb` / `fastboot` `37.0.1` | — | Auto-sparses raw 2.05 GiB `.img` into 5 chunks matching Huawei's `max-download-size` (450 MiB) | Android SDK Platform-Tools |

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

## 7. Post-Boot Notes & Restore Path

- **Offline SetupWizard & Play Store / SIM Hot-Plug Tips**:
  - `LeaOS 21.0` enables `WITH_ADB_INSECURE=true`, so wired ADB works right after first boot.
  - If Google SetupWizard hangs on *"Getting your phone ready..."* in a restricted network, skip Wi-Fi and finish SetupWizard offline, then sideload your proxy tool via `adb install`.
  - For Play Store "Install" button freeze during initial self-update (`adb shell am force-stop com.android.vending`) and EMUI 9.1 Balong baseband SIM hot-plug behavior (reboot once after inserting a SIM card), see Phase 4 of [huawei-enjoy9plus-a14-flash-guide](https://github.com/erha-erha/huawei-enjoy9plus-a14-flash-guide#5-phase-4-first-boot-proxy-setup-play-store-freeze--sim-card-hot-plug-fix).
- **Re-rooting with Magisk (Optional)**:
  - Keep the device unrooted until daily functions (calls, Wi-Fi, camera) are verified. If needed later, patch the clean `stock_recovery_ramdisk.img` (or restore your backed-up Magisk-patched `recovery_ramdisk.img`) and remember that on EMUI 9.1, Magisk shares the `recovery_ramdisk` partition with SHRP.
- **Returning to Stock EMUI `9.1.0.350`**:
  - Flash back your backed-up `system.img` and `stock_recovery_ramdisk.img` (plus `stock_kernel_350.img` if desired) via Fastboot, then Factory Reset in stock Recovery.
  - **Never** `fastboot flash` `oeminfo` or `nvme` — those partitions must only be restored via `dd` from a rooted shell if baseband/IMEI recovery is ever needed.

---

## 8. Troubleshooting Quick Reference

| Symptom / Error | Verified Root Cause | Solution |
| :--- | :--- | :--- |
| `adb exec-out su -c dd` backup fails SHA-256 on Windows | `su` PTY/newline conversion corrupts binary stream | `dd` to `/data/local/tmp/bak_<part>.img`, `adb -s <SERIAL> pull`, then verify SHA-256 |
| `splash2.img` SHA-256 always mismatches during backup | `/splash2` is mounted `rw` as a live ext4 log partition | Normal and expected; ignore mismatch |
| `adb reboot bootloader` reboots into normal EMUI | EMUI / Magisk `recovery_ramdisk` ignores soft bootloader reboot flag | Unplug USB, power off, hold **Volume Down** while plugging USB into PC |
| `fastboot devices` empty; Device Manager shows `HI3650` | Prior Zadig/`libwdi` INF (`hi3650.inf`) hijacks `VID_18D1&PID_D00D` without `{F72FE0D4-...}` GUID and locks `USBDevice` class | Admin PowerShell: `pnputil /delete-driver oemXX.inf /uninstall /force` so Windows falls back to inbox `winusb.inf` |
| Holding Volume Up + Power enters eRecovery instead of SHRP | USB cable was still plugged in | **Unplug USB first**, then hold Volume Up + Power until SHRP loads, then reconnect USB |
| Stuck on LineageOS 3-circle boot animation (> 5 min) | Stock EMUI 9.1 Recovery F2FS format triggers `F2FS-fs (sdd66): Invalid checksum crc` → `/data` unmounted → `credstore` crash loop | Flash `SHRP-Reborn v3.2 charlotte`, run `/system/bin/make_f2fs -f -O encrypt -w 4096 /dev/block/by-name/userdata`, verify `mount -t f2fs`, wipe `/cache`, reboot |
| SetupWizard stuck on *"Getting your phone ready..."* | Restricted network blocks Google check-in | Skip Wi-Fi to finish offline, sideload proxy via wired ADB, then sign in |
