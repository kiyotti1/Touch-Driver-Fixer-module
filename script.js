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
    // 1. ドライバの判別（実際に接続されているデバイスの存在を確認）
    let checkFts = await runCmd("[ -d '/sys/bus/i2c/drivers/fts_ts/3-0038' ] || [ -d '/sys/bus/i2c/drivers/fts_ts/3-0062' ] && echo 'FTS' || echo 'NOT'");
    let isFts = checkFts && checkFts.includes("FTS");

    let badge = document.getElementById("driver-status");
    if (isFts) {
        badge.textContent = "検出ドライバ: FTS (一部機能制限あり)";
        document.getElementById("palm-reject-container").style.opacity = "0.4";
        document.getElementById("inject-select").disabled = true;
    } else {
        badge.textContent = "検出ドライバ: NVT";
        document.getElementById("palm-reject-container").style.opacity = "1";
        document.getElementById("inject-select").disabled = false;
    }

    // 2. 設定ファイルの読み込み
    let rawConfig = await runCmd(`[ -f ${CONFIG_PATH} ] && cat ${CONFIG_PATH} || echo '{}'`);
    try {
        currentConfig = JSON.parse(rawConfig);
    } catch(e) {
        currentConfig = {};
    }

    // 3. UIコントロールの初期値設定
    const serviceSwitch = document.getElementById("service-switch");
    const injectSelect = document.getElementById("inject-select");
    const controlSelect = document.getElementById("control-select");
    const screenSelect = document.getElementById("screen-select");
    const govSelect = document.getElementById("cpu-governor-select");

    serviceSwitch.checked = currentConfig["_service_enabled"] !== "false";
    injectSelect.value = currentConfig["_inject_value"] || "4";
    controlSelect.value = currentConfig["_control_value"] || "on";
    screenSelect.value = currentConfig["_screen_update"] || "on";
    govSelect.value = currentConfig["_cpu_governor"] || "schedutil";

    // 4. イベントハンドラーの設定

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
        currentConfig["_inject_value"] = injectSelect.value;
        await saveConfig();
        showToast();
    });

    // Device Power Control ノードの書き込み (NVT / FTS 両対応)
    controlSelect.addEventListener("change", async () => {
        let val = controlSelect.value;
        currentConfig["_control_value"] = val;
        await saveConfig();
        
        let targets = [
            '/sys/bus/i2c/devices/3-0062/power/control',
            '/sys/bus/i2c/devices/3-0038/power/control'
        ];
        for (let target of targets) {
            await runCmd(`[ -e "${target}" ] && echo "${val}" > "${target}" 2>/dev/null`);
        }
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
        await runCmd(`for g in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -e "$g" ] && echo "${val}" > "$g" 2>/dev/null; done`);
    });
}

main();
