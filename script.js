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
    if (res.errno == 0) {
        return res.stdout;
    } else {
        console.error(`Command fail: ${cmd}`, res.stderr);
        return null;
    }
}

const CONFIG_PATH = '/data/adb/touch-reset_config.json';
let currentConfig = {};
let appTemplate = document.getElementById("app-template").content;
let appsList = document.getElementById("apps-list");

function sortApps() {
    [...appsList.children].sort((a, b) => {
        let aSelect = a.querySelector(".mode-select").value;
        let bSelect = b.querySelector(".mode-select").value;
        if (aSelect === "stable" && bSelect !== "stable") return -1;
        if (aSelect !== "stable" && bSelect === "stable") return 1;
        
        let aLabel = a.querySelector(".label").textContent.toLowerCase();
        let bLabel = b.querySelector(".label").textContent.toLowerCase();
        return aLabel.localeCompare(bLabel);
    }).forEach(el => appsList.appendChild(el));
}

function addAppElement(pkgName, appLabel, savedMode) {
    let node = document.importNode(appTemplate, !0);
    node.querySelector(".label").textContent = appLabel;
    node.querySelector(".pkg-name").textContent = pkgName;
    
    let select = node.querySelector(".mode-select");
    select.value = savedMode;
    
    select.addEventListener("change", async () => {
        if (select.value === "stable") {
            currentConfig[pkgName] = "stable";
        } else {
            delete currentConfig[pkgName];
        }
        let jsonStr = JSON.stringify(currentConfig);
        await runCmd(`echo '${jsonStr}' > ${CONFIG_PATH}`);
    });
    
    appsList.appendChild(node);
}

function getCleanLabel(pkgName) {
    const fixedMaps = {
        "com.android.settings": "設定",
        "com.android.systemui": "SystemUI",
        "com.google.android.gms": "Google Play 開発者サービス",
        "com.android.vending": "Google Play ストア",
        "com.android.chrome": "Chrome",
        "com.google.android.inputmethod.latin": "Gboard",
        "com.google.android.apps.nbu.files": "Files by Google",
        "com.google.android.apps.photos": "Google フォト",
        "com.google.android.apps.bard": "Gemini",
        "com.google.android.youtube": "YouTube",
        "com.google.android.googlequicksearchbox": "Googleアプリ",
        "com.google.android.apps.docs": "Google ドライブ",
        "com.google.android.calculator": "電卓",
        "com.google.android.calendar": "Google カレンダー",
        "com.google.android.contacts": "連絡帳",
        "com.google.android.deskclock": "時計",
        "com.google.android.gm": "Gmail",
        "com.openai.chatgpt": "ChatGPT",
        "com.termux": "Termux",
        "com.teslacoilsw.launcher": "Nova Launcher",
        "io.github.chipppppppppp.lime": "LIME",
        "io.github.yagiyuu.linextra": "LINExtra",
        "com.rookiestudio.perfectviewer": "Perfect Viewer",
        "org.adaway": "AdAway",
        "com.nisargjhaveri.netspeed": "NetSpeed Indicator",
        "dev.ukanth.ufirewall": "AFWall+",
        "org.crape.rotationcontrol": "画面回転制御",
        "ru.zdevs.zarchiver": "ZArchiver"
    };

    if (fixedMaps[pkgName]) return fixedMaps[pkgName];

    let lastPart = pkgName.split('.').pop();
    if (lastPart === "android" && pkgName.split('.').length > 1) {
        lastPart = pkgName.split('.').slice(-2)[0];
    }
    return lastPart.charAt(0).toUpperCase() + lastPart.slice(1);
}

async function main() {
    let configStr = await runCmd(`cat ${CONFIG_PATH} 2>/dev/null`);
    if (configStr && configStr.trim()) {
        try { currentConfig = JSON.parse(configStr); } catch(e) { currentConfig = {}; }
    }

    appsList.innerText = "アプリ一覧を読み込み中...";

    let userRaw = await runCmd("pm list packages -3");
    
    let finalPackages = new Set();
    if (userRaw) {
        userRaw.split("\n").forEach(line => {
            let p = line.split(":")[1];
            if (p && p.trim()) finalPackages.add(p.trim());
        });
    }

    const allowedSys = [
        "com.android.settings",
        "com.android.systemui",
        "com.google.android.gms",
        "com.android.vending",
        "com.android.chrome",
        "com.google.android.inputmethod.latin",
        "com.google.android.apps.nbu.files",
        "com.google.android.apps.photos"
    ];
    allowedSys.forEach(p => finalPackages.add(p));

    appsList.innerHTML = "";

    finalPackages.forEach(pkgName => {
        let label = getCleanLabel(pkgName);
        let savedMode = currentConfig[pkgName] || "fast";
        addAppElement(pkgName, label, savedMode);
    });

    sortApps();

    // ==========================================================
    // 検索機能・クリアボタン & 戻るキーの安全な制御
    // ==========================================================
    const searchInput = document.getElementById("search");
    const searchClear = document.getElementById("search-clear");
    let hasHistoryBackstep = false;

    function filterApps() {
        let val = searchInput.value.trim().toLowerCase();
        
        if (val) {
            searchClear.style.display = "block";
        } else {
            searchClear.style.display = "none";
        }

        if (!val) {
            [...appsList.children].forEach(el => el.style.display = "flex");
            return sortApps();
        }
        
        [...appsList.children].forEach(el => {
            let label = el.querySelector(".label").textContent.toLowerCase();
            let name = el.querySelector(".pkg-name").textContent.toLowerCase();
            if (label.includes(val) || name.includes(val)) {
                el.style.display = "flex";
            } else {
                el.style.display = "none";
            }
        });
    }

    searchInput.addEventListener("input", () => {
        let val = searchInput.value.trim().toLowerCase();
        
        if (val && !hasHistoryBackstep) {
            window.history.pushState({ isSearching: true }, "");
            hasHistoryBackstep = true;
        } else if (!val && hasHistoryBackstep) {
            hasHistoryBackstep = false;
            window.history.back();
        }
        
        filterApps();
    });

    window.addEventListener("popstate", (event) => {
        if (hasHistoryBackstep) {
            searchInput.value = "";
            hasHistoryBackstep = false;
            filterApps();
        }
    });

    searchClear.addEventListener("click", () => {
        searchInput.value = "";
        if (hasHistoryBackstep) {
            hasHistoryBackstep = false;
            window.history.back();
        }
        filterApps();
        searchInput.focus();
    });

    // ==========================================================
    // はてなボタンの開閉制御（追加部分）
    // ==========================================================
    const helpToggle = document.getElementById("help-toggle");
    const helpBox = document.getElementById("help-box");

    helpToggle.addEventListener("click", () => {
        if (helpBox.style.display === "block") {
            helpBox.style.display = "none";
        } else {
            helpBox.style.display = "block";
        }
    });
}

main();
