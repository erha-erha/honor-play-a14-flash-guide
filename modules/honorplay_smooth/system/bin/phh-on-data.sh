#!/system/bin/sh

vndk="$(getprop persist.sys.vndk)"
[ -z "$vndk" ] && vndk="$(getprop ro.vndk.version |grep -oE '^[0-9]+')"

if getprop persist.sys.phh.no_vendor_overlay |grep -q true;then
	for part in odm vendor;do
		grep -q " /$part/overlay " /proc/mounts 2>/dev/null || mount /mnt/phh/empty_dir/ /$part/overlay
	done
fi

if getprop persist.sys.phh.caf.media_profile |grep -q true;then
    setprop media.settings.xml "/vendor/etc/media_profiles_vendor.xml"
fi

if getprop persist.sys.phh.no_stock_apps |grep -q true; then
	for part in odm vendor; do
		grep -q " /$part/overlay " /proc/mounts 2>/dev/null || mount /mnt/phh/empty_dir/ /$part/overlay
		grep -q " /$part/app " /proc/mounts 2>/dev/null || mount /mnt/phh/empty_dir/ /$part/app
	done
fi

# Idempotent bind-mount guard: prevents TrebleDroid/LeaOS VNDK 28 2^N shared-peer mount bomb
safe_bind() {
    [ -f "$1" ] && [ -f "$2" ] || return 0
    grep -q " $2 " /proc/mounts 2>/dev/null || mount -o bind "$1" "$2"
}

minijailSrc=/system/system_ext/apex/com.android.vndk.v28/lib/libminijail.so
minijailSrc64=/system/system_ext/apex/com.android.vndk.v28/lib64/libminijail.so
if [ "$vndk" = 27 ];then
    safe_bind "$minijailSrc64" /vendor/lib64/libminijail_vendor.so
    safe_bind "$minijailSrc" /vendor/lib/libminijail_vendor.so
fi

if [ "$vndk" = 28 ];then
    safe_bind "$minijailSrc64" /vendor/lib64/libminijail_vendor.so
    safe_bind "$minijailSrc" /vendor/lib/libminijail_vendor.so
    safe_bind "$minijailSrc64" /vendor/lib64/libminijail.so
    safe_bind "$minijailSrc" /vendor/lib/libminijail.so
fi
