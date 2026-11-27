#!/system/bin/sh
HW=$(getprop ro.hardware)
ui_print "- Detected hardware: $HW"
if [ "$HW" != "kirin970" ]; then
  abort "! This module is strictly for Honor Play / Kirin 970 (found: $HW). Do NOT flash on Kirin 710!"
fi
if [ "$BOOTMODE" = "true" ] && [ ! -f /odm/etc/camera/ippalgoconfig.xml ]; then
  abort "! /odm/etc/camera/ippalgoconfig.xml not found on this ROM/device."
fi
set_perm "$MODPATH/post-fs-data.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
ui_print "- Honor Play (Kirin 970) Camera Scudo crash fix installed."
ui_print "- Patched ippalgoconfig.xml will be generated locally from stock /odm on next boot."
