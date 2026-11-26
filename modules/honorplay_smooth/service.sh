#!/system/bin/sh
# Honor Play (COR-AL10 / Kirin 970 + Mali-G72 MP12) - Smooth & Low-Latency Tweaks
while [ "$(getprop sys.boot_completed)" != "1" ]; do
  sleep 2
done
sleep 3

# 0. Stop LeaOS runaway debug logcat service if active
setprop ctl.stop dump-logs 2>/dev/null || true

# 1. Disable expensive Android 14 window blurs & set snappy 0.5x animations
settings put global disable_window_blurs 1 2>/dev/null || true
settings put global window_animation_scale 0.5 2>/dev/null || true
settings put global transition_animation_scale 0.5 2>/dev/null || true
settings put global animator_duration_scale 0.5 2>/dev/null || true

# 2. Kirin 970 policy0 (4x Cortex-A53, 509..1844 MHz) interactive governor
P0=/sys/devices/system/cpu/cpufreq/policy0/interactive
if [ -d "$P0" ]; then
  echo 10000 > $P0/timer_rate 2>/dev/null || true
  echo 75 > $P0/go_hispeed_load 2>/dev/null || true
  echo 1402000 > $P0/hispeed_freq 2>/dev/null || true
  echo 10000 > $P0/above_hispeed_delay 2>/dev/null || true
  echo "70 1018000:75 1210000:80 1402000:85 1690000:90" > $P0/target_loads 2>/dev/null || true
  echo 1 > $P0/io_is_busy 2>/dev/null || true
  echo 0 > $P0/fast_ramp_down 2>/dev/null || true
  echo 100000 > $P0/boostpulse_duration 2>/dev/null || true
fi

# 3. Kirin 970 policy4 (4x Cortex-A73, 682..2362 MHz) interactive governor - cut 118ms ramp lag
P4=/sys/devices/system/cpu/cpufreq/policy4/interactive
if [ -d "$P4" ]; then
  echo 10000 > $P4/timer_rate 2>/dev/null || true
  echo 70 > $P4/go_hispeed_load 2>/dev/null || true
  echo 1652000 > $P4/hispeed_freq 2>/dev/null || true
  echo "10000 1652000:15000" > $P4/above_hispeed_delay 2>/dev/null || true
  echo "65 1364000:70 1652000:80 1863000:88" > $P4/target_loads 2>/dev/null || true
  echo 1 > $P4/io_is_busy 2>/dev/null || true
  echo 0 > $P4/fast_ramp_down 2>/dev/null || true
  echo 120000 > $P4/boostpulse_duration 2>/dev/null || true
fi

# 4. Mali-G72 MP12 GPU (103..767 MHz) - raise wake floor from 237MHz -> 415MHz & scene 1 (550MHz hispeed)
if [ -w /sys/class/devfreq/gpufreq/min_freq ]; then
  echo 415000000 > /sys/class/devfreq/gpufreq/min_freq 2>/dev/null || true
fi
if [ -w /sys/class/devfreq/gpufreq/gpu_scene_aware/scene ]; then
  echo 1 > /sys/class/devfreq/gpufreq/gpu_scene_aware/scene 2>/dev/null || true
fi
