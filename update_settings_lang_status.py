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
        "settings_model_ready": "Model ready — on this device",
        "settings_downloading": "Downloading…",
        "settings_removed_restore": "Removed — tap Download to restore",
        "settings_not_downloaded": "Not yet downloaded"
    },
    'zh': {
        "settings_model_ready": "模型已准备好 — 在此设备上",
        "settings_downloading": "下载中…",
        "settings_removed_restore": "已移除 — 点击下载以恢复",
        "settings_not_downloaded": "尚未下载"
    },
    'ms': {
        "settings_model_ready": "Model sedia — pada peranti ini",
        "settings_downloading": "Memuat turun…",
        "settings_removed_restore": "Dialih keluar — ketik Muat Turun untuk memulihkan",
        "settings_not_downloaded": "Belum dimuat turun"
    },
    'ta': {
        "settings_model_ready": "மாதிரி தயார் — இந்தச் சாதனத்தில்",
        "settings_downloading": "பதிவிறக்குகிறது…",
        "settings_removed_restore": "அகற்றப்பட்டது — மீட்டமைக்க பதிவிறக்கு என்பதைத் தட்டவும்",
        "settings_not_downloaded": "இன்னும் பதிவிறக்கப்படவில்லை"
    }
}

for lang, filepath in files.items():
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        data.update(data_to_add[lang])
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

print("Status translations added successfully.")
