#!/system/bin/sh

# ==========================================================
# Touch Driver Fixer v2.1 - Core Service
# ==========================================================

CONFIG_FILE="/data/adb/touch-reset_config.json"
LOCK=/dev/.nvt_fix_running

# ----- デフォルト設定値 -----
INJECT_VAL="3"
SCREEN_UPD="on"
CPU_GOV="schedutil"
SERVICE_ENABLED="true"

# ----- JSON設定のパース -----
if [ -f "$CONFIG_FILE" ]; then
    INV=$(grep -o '"_inject_value":"[^"]*' "$CONFIG_FILE" | cut -d'"' -f4)
    [ ! -z "$INV" ] && INJECT_VAL="$INV"
    
    SCU=$(grep -o '"_screen_update":"[^"]*' "$CONFIG_FILE" | cut -d'"' -f4)
    [ ! -z "$SCU" ] && SCREEN_UPD="$SCU"
    
    CGV=$(grep -o '"_cpu_governor":"[^"]*' "$CONFIG_FILE" | cut -d'"' -f4)
    [ ! -z "$CGV" ] && CPU_GOV="$CGV"
    
    SVE=$(grep -o '"_service_enabled":[^,}]*' "$CONFIG_FILE" | cut -d':' -f2 | tr -d ' "')
    [ ! -z "$SVE" ] && SERVICE_ENABLED="$SVE"
fi

# ----- 高速モード（リバインド処理）の関数 -----
do_fast_rebind() {
    if [ -d "/sys/bus/i2c/drivers/NVT-ts" ]; then
        echo "3-0062" > "/sys/bus/i2c/drivers/NVT-ts/unbind" 2>/dev/null
        echo "3-0062" > "/sys/bus/i2c/drivers/NVT-ts/bind" 2>/dev/null
    elif [ -d "/sys/bus/i2c/drivers/fts_ts" ]; then
        for dev in $(ls /sys/bus/i2c/drivers/fts_ts/ | grep -E '^[0-9]+-[0-9a-fA-F]+$'); do
            echo "$dev" > "/sys/bus/i2c/drivers/fts_ts/unbind" 2>/dev/null
            echo "$dev" > "/sys/bus/i2c/drivers/fts_ts/bind" 2>/dev/null
        done
    fi
}

# 1. パームリジェクション値の初期適用
echo "$INJECT_VAL" > /sys/bus/i2c/devices/3-0062/tp_palm_reject 2>/dev/null

# 2. 画面プロファイル最適化の初期適用
for p in /sys/devices/platform/soc/soc:touch@/power/control /sys/devices/platform/soc/soc:touch/power/control
do
    [ -e "$p" ] && echo "$SCREEN_UPD" > "$p" 2>/dev/null
done

# 3. CPUガバナーの初期適用
for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
do
    [ -e "$g" ] && echo "$CPU_GOV" > "$g" 2>/dev/null
done

log -t TOUCH_FIXER "Initial settings applied. Governor: $CPU_GOV"

# 4. 画面更新サービスが「OFF」の場合の処理
if [ "$SERVICE_ENABLED" = "false" ]; then
    rm -f /data/adb/modules/touch-reset/system/usr/keylayout/mtk-kpd.kl 2>/dev/null
    rm -f /data/adb/modules/touch-reset/system/vendor/usr/keylayout/mtk-kpd.kl 2>/dev/null
    log -t TOUCH_FIXER "Update Service is OFF. HomeButton restored. Exit loop."
    exit 0
fi

log -t TOUCH_FIXER "Update Service is ON. Starting HomeButton monitor loop."

# 5. HOMEキー監視ループ
while true
do
    line=$(getevent -c 1 /dev/input/event1 2>/dev/null)

    # KEY_HOME UP 検知
    [ "$line" != "0001 0066 00000000" ] && continue
    [ -e "$LOCK" ] && continue

    (
        touch "$LOCK"

        # 最前面アプリのパッケージ名を取得
        FOCUS_INFO=$(dumpsys window | grep -E 'mCurrentFocus|mFocusedApp|mResumedActivity' | head -n 1)
        CURRENT_APP=$(echo "$FOCUS_INFO" | grep -oE '[a-zA-Z0-9._]+\/[a-zA-Z0-9._]+' | head -n 1 | cut -d/ -f1)
        if [ -z "$CURRENT_APP" ]; then
            CURRENT_APP=$(echo "$FOCUS_INFO" | grep -oE 'u0 [a-zA-Z0-9._]+' | head -n 1 | awk '{print $2}')
        fi
        
                # --- [修正] ここから判定ロジックを100%確実なものに変更 ---
        TARGET_MODE="fast"
        if [ -f "$CONFIG_FILE" ] && [ ! -z "$CURRENT_APP" ]; then
            # JSONから該当パッケージの設定値（"stable" または "fast"）を安全に抽出
            APP_SETTING=$(grep -o "\"${CURRENT_APP}\":\"[^\"]*" "$CONFIG_FILE" | cut -d'"' -f4)
            if [ "$APP_SETTING" = "stable" ]; then
                TARGET_MODE="stable"
            fi
        fi

        # リカバリ処理の実行
        if [ "$TARGET_MODE" = "stable" ]; then
            # 安定モード：プロシージャを直接叩く（バインド処理は走らない）
            cat /proc/nvt_selftest > /dev/null 2>/dev/null
            log -t TOUCH_FIXER "Recovery triggered: STABLE mode for $CURRENT_APP"
        else
            # 高速モード：ドライバのリバインドを実行
            do_fast_rebind
            log -t TOUCH_FIXER "Recovery triggered: FAST mode (rebind) for $CURRENT_APP"
        fi
        # --- 修正ここまで ---

        rm -f "$LOCK"
    ) &
done
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
