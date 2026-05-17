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

# 3. インストール処理の完全な終盤で「喝」を入れる
ui_print "- Preparing touch controller..."

(
  # 念のため1秒だけ待ち、Magiskのファイル配置が落ち着いた瞬間に叩く
  sleep 1
  
  # ワイルドカードを展開して安全に書き込み
  for control_path in /sys/devices/platform/soc/soc:touch@*/power/control; do
    if [ -e "$control_path" ]; then
      chmod 666 "$control_path" 2>/dev/null
      echo "on" > "$control_path"
      log -t HOMEKEY_MOD "Touch power control forced ON via customize.sh"
    fi
  done
) &

ui_print "- Touch power control triggered successfully!"
