#!/system/bin/sh
XML_SRC=""
for p in /system/product/etc/sysconfig/google.xml /product/etc/sysconfig/google.xml; do
  if [ -f "$p" ]; then
    XML_SRC="$p"
    break
  fi
done

if [ -z "$XML_SRC" ]; then
  abort "! google.xml not found in /system/product/etc/sysconfig/ (is this a GApps build?)"
fi

mkdir -p "$MODPATH/system/product/etc/sysconfig"
XML_DST="$MODPATH/system/product/etc/sysconfig/google.xml"
cp "$XML_SRC" "$XML_DST" || abort "! Failed to copy $XML_SRC"

if ! grep -q '<allow-in-power-save package="com.google.android.gms"' "$XML_DST"; then
  ui_print "- Note: allow-in-power-save entry for GMS was already absent or modified."
else
  sed -i 's|<allow-in-power-save package="com.google.android.gms" />|<!-- <allow-in-power-save package="com.google.android.gms" /> -->|' "$XML_DST"
  ui_print "- Patched local google.xml: removed com.google.android.gms from Doze power-save whitelist."
fi

set_perm "$XML_DST" 0 0 0644 u:object_r:system_file:s0
ui_print "- GMS Doze will activate via Magisk Magic Mount on next reboot."
