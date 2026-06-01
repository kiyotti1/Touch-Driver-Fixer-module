#!/system/bin/sh

# =====================================================================
# Touch-Driver-Fixer - Installation Script
# =====================================================================

# 1. 権限設定（最優先で実行）
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755

# 2. おすすめ併用モジュールの案内を表示
ui_print "***********************************************"
ui_print " 🔗 おすすめの併用モジュール:"
ui_print " 本モジュールを快適に使用するため、"
ui_print " 以下のモジュールとのセット導入を強く推奨します。"
ui_print " https://github.com/kiyotti1/HomeButton-Disable-Module"
ui_print "***********************************************"

ui_print "- 最適化中..."

echo 1 > /sys/bus/i2c/devices/3-0062/tp_palm_reject 2>/dev/null
echo on > /sys/devices/platform/soc/soc:touch@*/power/control 2>/dev/null

ui_print "- 完了"
