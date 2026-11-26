#!/system/bin/sh
# Honor Play (6 GB RAM) - Auto-enable 3 GiB LZ4 ZRAM on Magisk boot
for i in 1 2 3 4 5; do
  [ -e /sys/block/zram0/disksize ] && break
  sleep 1
done
[ -e /sys/block/zram0/disksize ] || exit 0

TARGET_BYTES=3221225472
CUR_SIZE=$(cat /sys/block/zram0/disksize 2>/dev/null)
if [ "$CUR_SIZE" != "$TARGET_BYTES" ] || ! grep -q '/dev/block/zram0' /proc/swaps 2>/dev/null; then
  /system/bin/swapoff /dev/block/zram0 2>/dev/null || true
  echo 1 > /sys/block/zram0/reset 2>/dev/null || true
  echo lz4 > /sys/block/zram0/comp_algorithm 2>/dev/null || true
  echo "$TARGET_BYTES" > /sys/block/zram0/disksize
  /system/bin/mkswap /dev/block/zram0 >/dev/null 2>&1
  /system/bin/swapon -p 100 /dev/block/zram0 >/dev/null 2>&1
fi
echo 0 > /proc/sys/vm/page-cluster 2>/dev/null || true
echo 80 > /proc/sys/vm/swappiness 2>/dev/null || true
