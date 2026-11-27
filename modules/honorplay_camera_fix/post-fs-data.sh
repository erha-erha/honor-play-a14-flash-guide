#!/system/bin/sh
MODDIR=${0%/*}
[ "$(getprop ro.hardware)" = "kirin970" ] || exit 0

TARGET=/odm/etc/camera/ippalgoconfig.xml
PATCHED="$MODDIR/ippalgoconfig.xml"
[ -f "$TARGET" ] || exit 0

# Generate patched config locally from stock /odm file (zero proprietary files redistributed)
if [ ! -f "$PATCHED" ]; then
  cp "$TARGET" "$PATCHED" || exit 0
  sed -i 's/<IppAlgo name="SmartAE" switcher="1"/<IppAlgo name="SmartAE" switcher="0"/' "$PATCHED"
fi

chmod 644 "$PATCHED"
chown root:root "$PATCHED"
chcon --reference="$TARGET" "$PATCHED" 2>/dev/null || chcon u:object_r:vendor_configs_file:s0 "$PATCHED" 2>/dev/null || true

if ! grep -q 'name="SmartAE" switcher="0"' "$TARGET" 2>/dev/null; then
  mount -o bind "$PATCHED" "$TARGET"
fi
