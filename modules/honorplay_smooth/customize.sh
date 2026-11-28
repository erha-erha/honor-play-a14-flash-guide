#!/system/bin/sh
HW=$(getprop ro.hardware)
ui_print "- Detected hardware: $HW"
if [ "$HW" != "kirin970" ]; then
  abort "! This module is strictly for Honor Play / Kirin 970 (found: $HW). Do NOT flash on Kirin 710!"
fi
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/system/bin/phh-on-boot.sh" 0 2000 0755 u:object_r:phhsu_exec:s0
set_perm "$MODPATH/system/bin/phh-on-data.sh" 0 2000 0755 u:object_r:phhsu_exec:s0
ui_print "- Honor Play (Kirin 970) smooth, low-latency (11.5ms SF phase) & mount-bomb fix v1.1.0 installed."
