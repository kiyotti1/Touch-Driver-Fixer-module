#!/system/bin/sh

# =====================================================================
# Touch Driver Fixer - Installation Script (v3.0)
# =====================================================================

ui_print "----------------------------------------"
ui_print "          Touch Driver Fixer v3.0"
ui_print "----------------------------------------"

# 1. 基本権限の設定
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755

# ドライバ環境判定と注意書き表示 (実際の接続デバイスのみで判定)
if [ -d "/sys/bus/i2c/drivers/fts_ts/3-0038" ] || [ -d "/sys/bus/i2c/drivers/fts_ts/3-0062" ]; then
    ui_print "- [注意] FTSドライバ環境を検出しました。"
    ui_print "  クラッシュ防止のため、カスタム.koの読み込みはスキップされます。"
    ui_print "  一部機能のみ利用可能です。"
else
    ui_print "- NVTドライバ環境を検出しました。"
fi

# 2. 設定ファイルの作成・初期化（すでに存在する場合は上書きしない）
CONFIG_FILE="/data/adb/touch-reset_config.json"
if [ -f "$CONFIG_FILE" ]; then
    ui_print "- 既存の設定ファイルを検出しました。データを維持します。"
else
    ui_print "- 初期設定ファイルを作成します。"
    cat << 'EOF' > "$CONFIG_FILE"
{"_service_enabled":"true","_inject_value":"4","_control_value":"on","_screen_update":"on","_cpu_governor":"schedutil"}
EOF
fi

# 3. Androidバージョンによるキーレイアウト上書きパスの修正
API_LEVEL=$(getprop ro.build.version.sdk)
SRC_VENDOR_KL="/vendor/usr/keylayout/mtk-kpd.kl"
SRC_SYSTEM_KL="/system/usr/keylayout/mtk-kpd.kl"

if [ "$API_LEVEL" -le 28 ]; then
    ui_print "- Android 9 以下の環境を検出しました (API: $API_LEVEL)"
    if [ -f "$SRC_SYSTEM_KL" ]; then
        DST_DIR="$MODPATH/system/usr/keylayout"
        mkdir -p "$DST_DIR"
        cp "$SRC_SYSTEM_KL" "$DST_DIR/mtk-kpd.kl"
        sed -Ei 's/^key[[:space:]]+102[[:space:]]+HOME([[:space:]].*)?$/key 102   UNKNOWN/' "$DST_DIR/mtk-kpd.kl"
        ui_print "- モジュール内 /system 側へホームボタン無効化を適用しました。"
    fi
else
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
