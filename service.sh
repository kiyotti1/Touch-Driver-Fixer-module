#!/system/bin/sh

# ==========================================================
# Touch Driver Fixer
# NVT Touch Recovery with WebUI App-Specific Config
# ==========================================================

# ----- 起動時に1回だけ -----
echo 4 > /sys/bus/i2c/devices/3-0062/tp_palm_reject 2>/dev/null

for p in /sys/devices/platform/soc/soc:touch@*/power/control
do
    [ -e "$p" ] && echo on > "$p" 2>/dev/null
done

log -t TOUCH_FIXER "service started"

# ----- 設定ファイルと多重起動防止 -----
# ★アップデートで消えないようにモジュール外の安全なパスに変更
CONFIG_FILE="/data/adb/touch-reset_config.json"
LOCK=/dev/.nvt_fix_running

# ----- HOMEキー監視 -----
while true
do
    line=$(getevent -c 1 /dev/input/event1 2>/dev/null)

    # KEY_HOME UP
    [ "$line" != "0001 0066 00000000" ] && continue
    [ -e "$LOCK" ] && continue

    (
        touch "$LOCK"

        # 1. 現在最前面にいるアプリのパッケージ名を取得 (SDカード内部ストレージ化対応強化版)
        FOCUS_INFO=$(dumpsys window | grep -E 'mCurrentFocus|mFocusedApp|mResumedActivity' | head -n 1)
        CURRENT_APP=$(echo "$FOCUS_INFO" | grep -oE '[a-zA-Z0-9._]+\/[a-zA-Z0-9._]+' | head -n 1 | cut -d/ -f1)
        
        if [ -z "$CURRENT_APP" ]; then
            CURRENT_APP=$(echo "$FOCUS_INFO" | grep -oE 'u0 [a-zA-Z0-9._]+' | head -n 1 | awk '{print $2}')
        fi
        
        # 2. デフォルトのモードは高速(fast)
        TARGET_MODE="fast"

        # 3. 設定ファイルが存在する場合、現在のアプリが「stable」に指定されているかチェック
        if [ -f "$CONFIG_FILE" ] && [ ! -z "$CURRENT_APP" ]; then
            if grep -q "\"${CURRENT_APP}\":\"stable\"" "$CONFIG_FILE"; then
                TARGET_MODE="stable"
            fi
        fi

        log -t TOUCH_FIXER "HOME UP -> App: $CURRENT_APP | Mode: $TARGET_MODE"

        # 4. モードに応じて分岐実行
        if [ "$TARGET_MODE" = "stable" ]; then
            cat /proc/nvt_selftest > /dev/null 2>/dev/null
        else
            echo "3-0062" > "/sys/bus/i2c/drivers/NVT-ts/unbind" 2>/dev/null
            sleep 0.05
            echo "3-0062" > "/sys/bus/i2c/drivers/NVT-ts/bind" 2>/dev/null
        fi

        rm -f "$LOCK"
    ) &
done
