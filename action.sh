#!/system/bin/sh

# ==========================================================
# Touch Driver Fixer - Action Script (KsuWebUI Launcher)
# ==========================================================

MOD_ID="touch-reset"

echo "----------------------------------------"
echo "        Touch Driver Fixer WebUI"
echo "----------------------------------------"

# 1. MMRL環境での実行をブロック（WebUIから開くよう促す）
if [ -n "$MMRL" ]; then
    echo "- このアクションはMMRL上での直接実行に対応していません。"
    echo "- モジュールカードをタップしてWebUIを開いてください。"
    exit 0
fi

# 2. 新しい KsuWebUI (adivenxnataly版) があるか確認して起動
if pm path io.github.adivenxnataly.ksuwebui >/dev/null 2>&1; then
    echo "- KsuWebUI (adivenxnataly) を検出しました。"
    echo "- 設定画面を起動します..."
    # adivenxnataly版は、引数「id」にモジュールIDを渡すことで直接開けます
    am start -n "io.github.adivenxnataly.ksuwebui/.MainActivity" -e id "$MOD_ID"
    exit 0
fi

# 3. フォールバック: 元の KSUWebUIStandalone (a13e300版) があるか確認して起動
if pm path io.github.a13e300.ksuwebui >/dev/null 2>&1; then
    echo "- 旧 KSUWebUIStandalone を検出しました。設定画面を起動します..."
    am start -n "io.github.a13e300.ksuwebui/.WebUIActivity" -e id "$MOD_ID"
    exit 0
fi

# 4. フォールバック: WebUI X (MMRL公式) があるか確認して起動
if pm path com.dergoogler.mmrl.webuix >/dev/null 2>&1; then
    echo "- WebUI X を検出しました。設定画面を起動します..."
    am start -n "com.dergoogler.mmrl.webuix/.ui.activity.webui.WebUIActivity" -e MOD_ID "$MOD_ID"
    exit 0
fi

# 5. どれも見つからない場合：KsuWebUIのインストールを促す
echo "! 警告: WebUIを表示するための「KsuWebUI」アプリが見つかりません。"
echo "- KernelSUマネージャー内の「ウェブUI」ボタンから直接開くか、"
echo "  KsuWebUI アプリをインストールしてください。"
echo ""
echo "5秒後に KsuWebUI のダウンロードページを開きます..."

sleep 5
am start -a android.intent.action.VIEW -d "https://github.com/adivenxnataly/KsuWebUI/releases"
exit 0
