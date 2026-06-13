let counter = 0;

function ksuExec(cmd, options = {}) {
    return new Promise((resolve, reject) => {
        let callbackName = `exec_callback_${Date.now()}_${counter++}`;
        window[callbackName] = (errno, stdout, stderr) => {
            delete window[callbackName];
            resolve({ errno, stdout, stderr });
        };
        try {
            ksu.exec(cmd, JSON.stringify(options), callbackName);
        } catch (e) {
            delete window[callbackName];
            reject(e);
        }
    });
}

async function runCmd(cmd) {
    let res = await ksuExec(cmd);
    if (res.errno == 0) return res.stdout;
    return null;
}

const CONFIG_PATH = '/data/adb/touch-reset_config.json';
const MOD_PATH = '/data/adb/modules/touch-reset';
let currentConfig = {};
let isNvtDriver = true;

// 主要Googleアプリ＋ご指定いただいたアプリのパッケージ名・表示名辞書
const APP_NAME_MAP = {
    "com.android.vending": "Google Play ストア",
    "com.google.android.apps.photos": "Google フォト",
    "com.google.android.apps.docs": "Google ドライブ",
    "com.google.android.gms": "Google Play 開発者サービス",
    "com.google.android.apps.bard": "Gemini",
    "jp.linecorp.linemusic.android": "LINE MUSIC",
    "jp.naver.line.android": "LINE",
    "jp.bookwalker.kreader.android.epub": "BOOK☆WALKER"
};

// トースト通知を表示する関数
function showToast() {
    const toast = document.getElementById("toast");
    toast.classList.add("show");
    setTimeout(() => {
        toast.classList.remove("show");
    }, 4000);
}

async function saveConfig() {
    let jsonStr = JSON.stringify(currentConfig);
    await runCmd(`cat << 'EOF' > ${CONFIG_PATH}\n${jsonStr}\nEOF`);
}

async function main() {
    // 1. ドライバの自動判別
    let checkNvt = await runCmd("[ -d '/sys/bus/i2c/drivers/NVT-ts/3-0062' ] && echo 'NVT' || echo 'NOT'");
    let checkFts = await runCmd("[ -d '/sys/bus/i2c/drivers/fts_ts' ] && echo 'FTS' || echo 'NOT'");
    
    let badge = document.getElementById("driver-status");
    if (checkNvt && checkNvt.includes("NVT")) {
        badge.textContent = "検出ドライバ: NVT";
        isNvtDriver = true;
    } else if (checkFts && checkFts.includes("FTS")) {
        badge.textContent = "検出ドライバ: FTS";
        isNvtDriver = false;
    } else {
        badge.textContent = "検出ドライバ: 汎用 (NVT互換動作)";
        isNvtDriver = true;
    }

    // 2. 設定ファイルの読み込み
    let rawConfig = await runCmd(`[ -f ${CONFIG_PATH} ] && cat ${CONFIG_PATH} || echo '{}'`);
    try {
        currentConfig = JSON.parse(rawConfig);
    } catch(e) {
        currentConfig = {};
    }

    // 3. UIコントロールの初期値セット
    const serviceSwitch = document.getElementById("service-switch");
    const injectSelect = document.getElementById("inject-select");
    const screenSelect = document.getElementById("screen-select");
    const govSelect = document.getElementById("cpu-governor-select");

    serviceSwitch.checked = currentConfig["_service_enabled"] !== "false";
    injectSelect.value = currentConfig["_inject_value"] || "3";
    screenSelect.value = currentConfig["_screen_update"] || "on";
    govSelect.value = currentConfig["_cpu_governor"] || "schedutil";

    // 画面更新サービス（トグル）切り替えイベント
    serviceSwitch.addEventListener("change", async () => {
        let isChecked = serviceSwitch.checked;
        currentConfig["_service_enabled"] = isChecked ? "true" : "false";
        await saveConfig();
        showToast();

        if (isChecked) {
            let cmdOn = `
                SRC_SYSTEM_KL="/system/usr/keylayout/mtk-kpd.kl"
                SRC_VENDOR_KL="/vendor/usr/keylayout/mtk-kpd.kl"
                if [ -f "$SRC_SYSTEM_KL" ]; then
                    mkdir -p "${MOD_PATH}/system/usr/keylayout"
                    cp "$SRC_SYSTEM_KL" "${MOD_PATH}/system/usr/keylayout/mtk-kpd.kl"
                    sed -Ei 's/^key[[:space:]]+102[[:space:]]+HOME([[:space:]].*)?$/key 102   UNKNOWN/' "${MOD_PATH}/system/usr/keylayout/mtk-kpd.kl"
                fi
                if [ -f "$SRC_VENDOR_KL" ]; then
                    mkdir -p "${MOD_PATH}/system/vendor/usr/keylayout"
                    cp "$SRC_VENDOR_KL" "${MOD_PATH}/system/vendor/usr/keylayout/mtk-kpd.kl"
                    sed -Ei 's/^key[[:space:]]+102[[:space:]]+HOME([[:space:]].*)?$/key 102   UNKNOWN/' "${MOD_PATH}/system/vendor/usr/keylayout/mtk-kpd.kl"
                fi
            `;
            await runCmd(cmdOn);
        } else {
            let cmdOff = `
                rm -f "${MOD_PATH}/system/usr/keylayout/mtk-kpd.kl" 2>/dev/null
                rm -f "${MOD_PATH}/system/vendor/usr/keylayout/mtk-kpd.kl" 2>/dev/null
            `;
            await runCmd(cmdOff);
        }
    });

    injectSelect.addEventListener("change", async () => {
        let val = injectSelect.value;
        currentConfig["_inject_value"] = val;
        await saveConfig();
        await runCmd(`echo ${val} > /sys/bus/i2c/devices/3-0062/tp_palm_reject 2>/dev/null`);
    });

    screenSelect.addEventListener("change", async () => {
        let val = screenSelect.value;
        currentConfig["_screen_update"] = val;
        await saveConfig();
        for (let p of ['/sys/devices/platform/soc/soc:touch@/power/control', '/sys/devices/platform/soc/soc:touch/power/control']) {
            await runCmd(`for f in ${p}; do [ -e "$f" ] && echo ${val} > "$f"; done 2>/dev/null`);
        }
    });

    govSelect.addEventListener("change", async () => {
        let val = govSelect.value;
        currentConfig["_cpu_governor"] = val;
        await saveConfig();
        await runCmd(`for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -e "$g" ] && echo "${val}" > "$g"; done 2>/dev/null`);
    });

    // 4. ナビゲーション
    const navTouch = document.getElementById("nav-touch");
    const navPerf = document.getElementById("nav-perf");
    const pageTouch = document.getElementById("page-touch");
    const pagePerf = document.getElementById("page-perf");

    navTouch.addEventListener("click", () => {
        navTouch.classList.add("active");
        navPerf.classList.remove("active");
        pageTouch.classList.add("active");
        pagePerf.classList.remove("active");
    });

    navPerf.addEventListener("click", () => {
        navPerf.classList.add("active");
        navTouch.classList.remove("active");
        pagePerf.classList.add("active");
        pageTouch.classList.remove("active");
    });

    // 5. アプリ一覧のビルド
    const appsList = document.getElementById("apps-list");
    const searchInput = document.getElementById("search");
    const searchClear = document.getElementById("search-clear");
    const appTemplate = document.getElementById("app-template").content;

    // サードパーティアプリ一覧を取得
    let rawApps = await runCmd("pm list packages -3");
    let packages = rawApps ? rawApps.split("\n")
                                   .map(line => line.replace("package:", "").trim())
                                   .filter(p => p.length > 0) : [];

    // 主要Googleアプリ5つのうち、実機にインストールされているものだけを選別して合流させる
    const coreGooglePkgs = [
        "com.android.vending",
        "com.google.android.apps.photos",
        "com.google.android.apps.docs",
        "com.google.android.gms",
        "com.google.android.apps.bard"
    ];

    for (let gPkg of coreGooglePkgs) {
        let isInstalled = await runCmd(`pm path ${gPkg} >/dev/null 2>&1 && echo "YES" || echo "NO"`);
        if (isInstalled && isInstalled.includes("YES")) {
            packages.push(gPkg);
        }
    }

    // 重複を除去してソート
    packages = Array.from(new Set(packages));

    // アプリ表示用レンダリング関数
    function renderAppList() {
        // 安定設定を最上位、それ以外は名前順ソート
        packages.sort((a, b) => {
            let modeA = currentConfig[a] || "fast";
            let modeB = currentConfig[b] || "fast";
            if (modeA === "stable" && modeB !== "stable") return -1;
            if (modeA !== "stable" && modeB === "stable") return 1;
            
            let nameA = APP_NAME_MAP[a] || a.split(".").pop();
            let nameB = APP_NAME_MAP[b] || b.split(".").pop();
            return nameA.localeCompare(nameB);
        });

        appsList.textContent = "";

        for (let pkg of packages) {
            let appNode = document.importNode(appTemplate, true);
            let itemDiv = appNode.querySelector(".app-item");
            let labelEl = appNode.querySelector(".app-label");
            let pkgEl = appNode.querySelector(".app-pkg");
            let selectEl = appNode.querySelector(".mode-select");
            let optStable = appNode.querySelector("#opt-stable");

            // 辞書にあれば綺麗な日本語名、なければパッケージ末尾名
            labelEl.textContent = APP_NAME_MAP[pkg] || pkg.split(".").pop();
            pkgEl.textContent = pkg;
            
            if (!isNvtDriver && optStable) {
                optStable.textContent = "安定 (FTS時は高速リバインドにフォールバック)";
            }

            let currentMode = currentConfig[pkg] || "fast";
            selectEl.value = currentMode;

            if (currentMode === "stable") {
                itemDiv.classList.add("pinned");
            }

            selectEl.addEventListener("change", async () => {
                currentConfig[pkg] = selectEl.value;
                await saveConfig();
                renderAppList();
                filterApps();
            });

            appsList.appendChild(appNode);
        }
    }

    // アプリ検索機能
    function filterApps() {
        let val = searchInput.value.trim().toLowerCase();
        searchClear.style.display = val ? "block" : "none";
        
        let items = appsList.getElementsByClassName("app-item");
        for (let item of items) {
            let label = item.querySelector(".app-label").textContent.toLowerCase();
            let pkg = item.querySelector(".app-pkg").textContent.toLowerCase();
            if (label.includes(val) || pkg.includes(val)) {
                item.style.display = "flex";
            } else {
                item.style.display = "none";
            }
        }
    }

    renderAppList();

    searchInput.addEventListener("input", filterApps);
    searchClear.addEventListener("click", () => {
        searchInput.value = "";
        filterApps();
        searchInput.focus();
    });
}

main();
