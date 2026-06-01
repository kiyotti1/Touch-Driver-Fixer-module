#!/system/bin/sh

# ==========================================================
# Touch Driver Fixer
# NVT Touch Recovery
# ==========================================================

# ----- 起動時に1回だけ -----

echo 1 > /sys/bus/i2c/devices/3-0062/tp_palm_reject 2>/dev/null

for p in /sys/devices/platform/soc/soc:touch@*/power/control
do
    [ -e "$p" ] && echo on > "$p" 2>/dev/null
done

log -t TOUCH_FIXER "service started"

# ----- 多重起動防止 -----

LOCK=/dev/.nvt_fix_running

# ----- HOMEキー監視 -----

while true
do
    line=$(getevent -c 1 /dev/input/event1 2>/dev/null)

    # KEY_HOME UP
    [ "$line" != "0001 0066 00000000" ] && continue

    # selftest実行中なら無視
    [ -e "$LOCK" ] && continue

    (
        touch "$LOCK"

        log -t TOUCH_FIXER "HOME UP -> NVT selftest"

        cat /proc/nvt_selftest > /dev/null 2>/dev/null

        rm -f "$LOCK"
    ) &
done        # UP (離された): 保留フラグをセット
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
