#!/system/bin/sh
HW=$(getprop ro.hardware)
ui_print "- Detected hardware: $HW"
if [ "$HW" != "kirin970" ]; then
  abort "! This module is strictly for Honor Play / Kirin 970 (found: $HW). Do NOT flash on Kirin 710!"
fi
set_perm "$MODPATH/service.sh" 0 0 0755
ui_print "- Honor Play (Kirin 970) smooth & low-latency tweaks installed."
