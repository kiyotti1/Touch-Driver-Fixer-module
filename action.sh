#!/system/bin/sh

# ==========================================================
# Touch Driver Fixer - Action Script (KsuWebUI Launcher)
# ==========================================================

MOD_ID="touch-reset"
RELEASE_URL="https://github.com/adivenxnataly/KsuWebUI/releases"

echo "----------------------------------------"
echo "        Touch Driver Fixer WebUI"
echo "----------------------------------------"

# 1. MMRL環境での実行をブロック（WebUIから開くよう促す）
if [ -n "$MMRL" ]; then
    echo "- このアクションはMMRL上での直接実行に対応していません。"
    echo "- モジュールカードをタップしてWebUIを開いてください。"
    exit 0
fi

# 2. 新しい KsuWebUI (adivenxnataly版) があるか確認して即時起動
if pm path io.github.adivenxnataly.ksuwebui >/dev/null 2>&1; then
    echo "- KsuWebUI (adivenxnataly) を検出しました。"
    echo "- 設定画面を起動します..."
    am start -n "io.github.adivenxnataly.ksuwebui/.MainActivity" -e id "$MOD_ID"
    exit 0
fi

# 3. フォールバック: 元の KSUWebUIStandalone (a13e300版) があるか確認して即時起動
if pm path io.github.a13e300.ksuwebui >/dev/null 2>&1; then
    echo "- 旧 KSUWebUIStandalone を検出しました。設定画面を起動します..."
    am start -n "io.github.a13e300.ksuwebui/.WebUIActivity" -e id "$MOD_ID"
    exit 0
fi

# 4. どちらも存在しない場合、自動的にブラウザでGitHubのリリースページを開く (--user 0 明示)
echo "- エラー: KsuWebUI アプリが見つかりません。"
echo "- ブラウザで KsuWebUI のダウンロードページを開きます..."
am start --user 0 -a android.intent.action.VIEW -d "$RELEASE_URL" >/dev/null 2>&1
