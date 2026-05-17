#!/system/bin/sh

set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755

echo on > /sys/devices/platform/soc/soc:touch@*/power/control 2>/dev/null || true
