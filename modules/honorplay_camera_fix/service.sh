#!/system/bin/sh
MODDIR=${0%/*}
[ "$(getprop ro.hardware)" = "kirin970" ] || exit 0

while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
done
sleep 2

TARGET=/odm/etc/camera/ippalgoconfig.xml
PATCHED="$MODDIR/ippalgoconfig.xml"
[ -f "$TARGET" ] || exit 0

if ! grep -q 'name="SmartAE" switcher="0"' "$TARGET" 2>/dev/null; then
  if [ ! -f "$PATCHED" ]; then
    cp "$TARGET" "$PATCHED" || exit 0
    sed -i 's/<IppAlgo name="SmartAE" switcher="1"/<IppAlgo name="SmartAE" switcher="0"/' "$PATCHED"
  fi
  chmod 644 "$PATCHED"
  chown root:root "$PATCHED"
  chcon --reference="$TARGET" "$PATCHED" 2>/dev/null || chcon u:object_r:vendor_configs_file:s0 "$PATCHED" 2>/dev/null || true
  mount -o bind "$PATCHED" "$TARGET" && killall CameraDaemon 2>/dev/null || true
fi
