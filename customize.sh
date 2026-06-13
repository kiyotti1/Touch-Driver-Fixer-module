#!/system/bin/sh

# =====================================================================
# Touch Driver Fixer - Installation Script (v2.1 Mount Fixed)
# =====================================================================

ui_print "----------------------------------------"
ui_print "          Touch Driver Fixer v2.1"
ui_print "----------------------------------------"

# 1. 基本権限の設定
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755

# 2. タッチパネルの初期最適化処理 (初期値: 3)
echo 3 > /sys/bus/i2c/devices/3-0062/tp_palm_reject 2>/dev/null
for p in /sys/devices/platform/soc/soc:touch@*/power/control
do
    [ -e "$p" ] && echo on > "$p" 2>/dev/null
done

# 3. 設定ファイルの維持
NEW_CONFIG="/data/adb/touch-reset_config.json"
if [ -f "$NEW_CONFIG" ]; then
    ui_print "- 既存の設定ファイルを検出しました。データを維持します。"
fi

# 4. Androidバージョンによるキーレイアウト上書きパスの修正
API_LEVEL=$(getprop ro.build.version.sdk)
SRC_VENDOR_KL="/vendor/usr/keylayout/mtk-kpd.kl"
SRC_SYSTEM_KL="/system/usr/keylayout/mtk-kpd.kl"

if [ "$API_LEVEL" -le 28 ]; then
    # 【Android 9 以下】/system/usr/keylayout/
    ui_print "- Android 9 以下の環境を検出しました (API: $API_LEVEL)"
    if [ -f "$SRC_SYSTEM_KL" ]; then
        DST_DIR="$MODPATH/system/usr/keylayout"
        mkdir -p "$DST_DIR"
        cp "$SRC_SYSTEM_KL" "$DST_DIR/mtk-kpd.kl"
        sed -Ei 's/^key[[:space:]]+102[[:space:]]+HOME([[:space:]].*)?$/key 102   UNKNOWN/' "$DST_DIR/mtk-kpd.kl"
        ui_print "- モジュール内 /system 側へホームボタン無効化を適用しました。"
    fi
else
    # 【Android 10 〜 13】 Magisk/KSUのルールに従い /system/vendor/usr/keylayout/ へ配置
    ui_print "- Android 10 以上の環境を検出しました (API: $API_LEVEL)"
    if [ -f "$SRC_VENDOR_KL" ]; then
        DST_DIR="$MODPATH/system/vendor/usr/keylayout"
        mkdir -p "$DST_DIR"
        cp "$SRC_VENDOR_KL" "$DST_DIR/mtk-kpd.kl"
        sed -Ei 's/^key[[:space:]]+102[[:space:]]+HOME([[:space:]].*)?$/key 102   UNKNOWN/' "$DST_DIR/mtk-kpd.kl"
        ui_print "- モジュール内 /system/vendor 側へホームボタン無効化を適用しました。"
    fi
fi

ui_print "----------------------------------------"
ui_print " インストール完了。再起動してください。"
ui_print "----------------------------------------"
