#!/system/bin/sh

# =====================================================================
# Touch Driver Fixer - Installation Script (v2.0)
# =====================================================================

ui_print "----------------------------------------"
ui_print "          Touch Driver Fixer v2.0"
ui_print "----------------------------------------"

# 1. 基本権限の設定
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm $MODPATH/service.sh 0 0 0755

# 2. タッチパネルの即時最適化処理 (インストール時に実行)
ui_print "- タッチパネルの最適化を適用しています..."
echo 4 > /sys/bus/i2c/devices/3-0062/tp_palm_reject 2>/dev/null
for p in /sys/devices/platform/soc/soc:touch@*/power/control
do
    [ -e "$p" ] && echo on > "$p" 2>/dev/null
done

# 3. 設定ファイルの自動引き継ぎ・退避処理 (アップデート対策)
OLD_CONFIG="/data/adb/modules/touch-reset/mode_config.json"
NEW_CONFIG="/data/adb/touch-reset_config.json"

if [ -f "$OLD_CONFIG" ]; then
    ui_print "- 以前の設定ファイルを検出しました。安全な場所へ保存します。"
    mv "$OLD_CONFIG" "$NEW_CONFIG"
    set_perm "$NEW_CONFIG" 0 0 0644
fi

# 4. 古い単体モジュールからの自動引き継ぎ・削除処理
OLD_HOME_MOD="/data/adb/modules/homebutton-disable"
SRC="/system/usr/keylayout/mtk-kpd.kl"
DSTDIR="$MODPATH/system/usr/keylayout"
DST="$DSTDIR/mtk-kpd.kl"

mkdir -p "$DSTDIR"

if [ -d "$OLD_HOME_MOD" ]; then
    ui_print "- 以前のホームボタン無効化モジュールを検出しました。"
    ui_print "  -> 設定を引き継ぎ、古いモジュールを安全に削除します。"
    
    if [ -f "$OLD_HOME_MOD/system/usr/keylayout/mtk-kpd.kl" ]; then
        cp "$OLD_HOME_MOD/system/usr/keylayout/mtk-kpd.kl" "$DST"
    else
        cp "$SRC" "$DST"
    fi
    
    rm -rf "$OLD_HOME_MOD"
else
    cp "$SRC" "$DST"
fi

# 5. ホームボタン無効化の加工処理
if grep -Eq '^key[[:space:]]+102[[:space:]]+HOME([[:space:]].*)?$' "$DST"; then
    sed -Ei '/^key[[:space:]]+102[[:space:]]+HOME([[:space:]].*)?$/d' "$DST"
    ui_print "- ホームボタンの無効化処理を適用しました。"
else
    ui_print "- ホームボタンはすでに無効化されています。"
fi

ui_print "----------------------------------------"
ui_print " インストールが完了しました。再起動してください。"
ui_print "----------------------------------------"
