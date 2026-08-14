#!/system/bin/sh

# ==========================================================
# Touch Driver Fixer v3.0 - Core Service (FTS Compatible)
# ==========================================================

CONFIG_FILE="/data/adb/touch-reset_config.json"
LOCK=/dev/.nvt_fix_running
MODPATH="/data/adb/modules/touch-reset"

# ----- デフォルト設定値 -----
INJECT_VAL="4"
SCREEN_UPD="on"
CONTROL_VAL="on"
CPU_GOV="schedutil"
SERVICE_ENABLED="true"

# ----- JSON設定のパース -----
if [ -f "$CONFIG_FILE" ]; then
    INV=$(grep -o '"_inject_value":"[^"]*' "$CONFIG_FILE" | cut -d'"' -f4)
    [ ! -z "$INV" ] && INJECT_VAL="$INV"
    
    SCU=$(grep -o '"_screen_update":"[^"]*' "$CONFIG_FILE" | cut -d'"' -f4)
    [ ! -z "$SCU" ] && SCREEN_UPD="$SCU"

    CTL=$(grep -o '"_control_value":"[^"]*' "$CONFIG_FILE" | cut -d'"' -f4)
    [ ! -z "$CTL" ] && CONTROL_VAL="$CTL"
    
    CGV=$(grep -o '"_cpu_governor":"[^"]*' "$CONFIG_FILE" | cut -d'"' -f4)
    [ ! -z "$CGV" ] && CPU_GOV="$CGV"
    
    SVE=$(grep -o '"_service_enabled":[^,}]*' "$CONFIG_FILE" | cut -d':' -f2 | tr -d ' "')
    [ ! -z "$SVE" ] && SERVICE_ENABLED="$SVE"
fi

# FTS ドライバ判別 (デバイスノードが存在する場合のみFTSとして扱う)
IS_FTS=0
if [ -d "/sys/bus/i2c/drivers/fts_ts/3-0038" ] || [ -d "/sys/bus/i2c/drivers/fts_ts/3-0062" ]; then
    IS_FTS=1
fi

# ==========================================================
# 起動時初期化シーケンス
# ==========================================================
log -t TOUCH_FIXER "Starting v3.0 Init Sequence..."

if [ $IS_FTS -eq 1 ]; then
    # --- FTS環境 ---
    log -t TOUCH_FIXER "FTS driver detected. Skipping custom .ko load to prevent crash."
else
    # --- NVT環境 ---
    echo "$INJECT_VAL" > /sys/bus/i2c/devices/3-0062/tp_palm_reject 2>/dev/null

    INSMOD_SUCCESS=0
    if [ -f "$MODPATH/nvt_ts.ko" ]; then
        echo "3-0062" > /sys/bus/i2c/drivers/NVT-ts/unbind 2>/dev/null
        insmod "$MODPATH/nvt_ts.ko" 2>/dev/null
        if [ $? -eq 0 ]; then
            INSMOD_SUCCESS=1
            log -t TOUCH_FIXER "Custom nvt_ts.ko inserted."
        fi
    fi

    if [ $INSMOD_SUCCESS -eq 1 ]; then
        echo "3-0062" > /sys/bus/i2c/drivers/NVT-ts/bind 2>/dev/null
        echo "1" > /sys/bus/i2c/devices/3-0062/tp_fw_updating 2>/dev/null
        echo "1" > /sys/bus/i2c/devices/3-0062/nvt_charger_plugin 2>/dev/null
    else
        echo "3-0062" > /sys/bus/i2c/drivers/NVT-ts/bind 2>/dev/null
        log -t TOUCH_FIXER "Fallback to stock NVT driver."
    fi
fi

# Device Power Control ノードの更新 (NVT: 3-0062, FTS: 3-0038)
for ctrl in \
    /sys/bus/i2c/devices/3-0062/power/control \
    /sys/bus/i2c/devices/3-0038/power/control
do
    [ -e "$ctrl" ] && echo "$CONTROL_VAL" > "$ctrl" 2>/dev/null
done

# 画面プロファイル & CPUガバナー設定
for p in /sys/devices/platform/soc/soc:touch@/power/control /sys/devices/platform/soc/soc:touch/power/control
do
    [ -e "$p" ] && echo "$SCREEN_UPD" > "$p" 2>/dev/null
done

for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
do
    [ -e "$g" ] && echo "$CPU_GOV" > "$g" 2>/dev/null
done

# ==========================================================
# 監視ループ制御
# ==========================================================
if [ "$SERVICE_ENABLED" = "false" ]; then
    rm -f /data/adb/modules/touch-reset/system/usr/keylayout/mtk-kpd.kl 2>/dev/null
    rm -f /data/adb/modules/touch-reset/system/vendor/usr/keylayout/mtk-kpd.kl 2>/dev/null
    log -t TOUCH_FIXER "Service OFF. Exit loop."
    exit 0
fi

# HOMEキー監視ループ (復旧トリガー)
while true
do
    line=$(getevent -c 1 /dev/input/event1 2>/dev/null)

    [ "$line" != "0001 0066 00000000" ] && continue
    [ -e "$LOCK" ] && continue

    (
        touch "$LOCK"

           if [ $IS_FTS -eq 1 ]; then
            # FTSの場合は存在するデバイスID（3-0038 または 3-0062）を特定して unbind -> bind
            FTS_DEV=""
            if [ -d "/sys/bus/i2c/drivers/fts_ts/3-0038" ]; then
                FTS_DEV="3-0038"
            elif [ -d "/sys/bus/i2c/drivers/fts_ts/3-0062" ]; then
                FTS_DEV="3-0062"
            fi

            if [ -n "$FTS_DEV" ]; then
                echo "$FTS_DEV" > /sys/bus/i2c/drivers/fts_ts/unbind 2>/dev/null
                echo "$FTS_DEV" > /sys/bus/i2c/drivers/fts_ts/bind 2>/dev/null
                log -t TOUCH_FIXER "FTS Recovery triggered: unbind/bind executed ($FTS_DEV)."
            fi
        else
            # NVT の場合は nvt_quick_reset を直接実行
            if [ -e "/sys/bus/i2c/devices/3-0062/nvt_quick_reset" ]; then
                echo "1" > /sys/bus/i2c/devices/3-0062/nvt_quick_reset 2>/dev/null
                log -t TOUCH_FIXER "NVT Recovery triggered: nvt_quick_reset executed."
            else
                echo "3-0062" > /sys/bus/i2c/drivers/NVT-ts/unbind 2>/dev/null
                echo "3-0062" > /sys/bus/i2c/drivers/NVT-ts/bind 2>/dev/null
                log -t TOUCH_FIXER "NVT Fallback Recovery triggered: Rebind executed."
            fi
        fi

        rm -f "$LOCK"
    ) &
done

