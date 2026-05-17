#!/system/bin/sh
# =====================================================================
# Home Key Touch-Driver Rebinder (Final Module Version)
# =====================================================================

# --- 設定項目 ---
DEV="/dev/input/event1"
DRV="NVT-ts"
NODE="3-0062"
WAIT_TIME=450000 # 0.32秒

# --- 競合防止 ---
# 既に同じスクリプトが動いている場合は、古い方を落として二重起動を防ぐ
MY_PID=$$
OLD_PIDS=$(pgrep -f "service.sh" | grep -v "$MY_PID")
if [ -n "$OLD_PIDS" ]; then
  kill -9 $OLD_PIDS 2>/dev/null
fi

log -t HOMEKEY_MOD "監視サービスがバックグラウンドで起動しました (PID: $MY_PID)"

# --- メイン処理 ---
click_pending=0

while true; do
  # 詰まりを起こさない単発取得モード
  line=$(getevent -c 1 "$DEV" 2>/dev/null)
  [ -z "$line" ] && continue

  if echo "$line" | grep -q "0066"; then
    case "$line" in
      *00000001*)
        # DOWN (押された): 保留をクリア
        click_pending=0
        ;;
      *)
        # UP (離された): 保留フラグをセット
        click_pending=1
        ;;
    esac
  fi

  # シングルタップ判定の保留監視
  if [ "$click_pending" -eq 1 ]; then
    usleep $WAIT_TIME 2>/dev/null || sleep 0.45
    
    if [ "$click_pending" -eq 1 ]; then
      click_pending=0 

      log -t HOMEKEY_MOD "リバインドを実行します"

      if [ -e "/sys/bus/i2c/drivers/$DRV/unbind" ]; then
        echo "$NODE" > "/sys/bus/i2c/drivers/$DRV/unbind"
        sleep 0.05
        echo "$NODE" > "/sys/bus/i2c/drivers/$DRV/bind"
      fi
    fi
  fi
done
