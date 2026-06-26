import json
import os

files = {
    'en': 'assets/translations/en.json',
    'zh': 'assets/translations/zh.json',
    'ms': 'assets/translations/ms.json',
    'ta': 'assets/translations/ta.json'
}

data_to_add = {
    'en': {
        "start_scan": "Start Scan",
        "home_current_scan_mode": "Current Scan Mode:",
        "home_scan_mode_ai": "AI (Uses Daily Limit)",
        "home_scan_mode_local": "Local (Offline & Free)"
    },
    'zh': {
        "start_scan": "开始扫描",
        "home_current_scan_mode": "当前扫描模式：",
        "home_scan_mode_ai": "AI (使用每日限额)",
        "home_scan_mode_local": "本地 (离线且免费)"
    },
    'ms': {
        "start_scan": "Mula Imbasan",
        "home_current_scan_mode": "Mod Imbasan Semasa:",
        "home_scan_mode_ai": "AI (Guna Had Harian)",
        "home_scan_mode_local": "Tempatan (Luar Talian & Percuma)"
    },
    'ta': {
        "start_scan": "ஸ்கேன் தொடங்கவும்",
        "home_current_scan_mode": "தற்போதைய ஸ்கேன் பயன்முறை:",
        "home_scan_mode_ai": "AI (தினசரி வரம்பைப் பயன்படுத்துகிறது)",
        "home_scan_mode_local": "உள்ளூர் (ஆஃப்லைன் & இலவசம்)"
    }
}

for lang, filepath in files.items():
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        data.update(data_to_add[lang])
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

print("Translation strings added successfully.")
