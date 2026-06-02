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
        "settings_select": "Select",
        "settings_selected": "Selected",
        "settings_download": "Download",
        "settings_remove": "Remove",
        "settings_sign_out": "Sign Out",
        "settings_add_lang_hint": "Add a language…"
    },
    'zh': {
        "settings_select": "选择",
        "settings_selected": "已选择",
        "settings_download": "下载",
        "settings_remove": "移除",
        "settings_sign_out": "退出",
        "settings_add_lang_hint": "添加语言…"
    },
    'ms': {
        "settings_select": "Pilih",
        "settings_selected": "Dipilih",
        "settings_download": "Muat Turun",
        "settings_remove": "Alih Keluar",
        "settings_sign_out": "Log Keluar",
        "settings_add_lang_hint": "Tambah bahasa…"
    },
    'ta': {
        "settings_select": "தேர்ந்தெடு",
        "settings_selected": "தேர்ந்தெடுக்கப்பட்டது",
        "settings_download": "பதிவிறக்கு",
        "settings_remove": "அகற்று",
        "settings_sign_out": "வெளியேறு",
        "settings_add_lang_hint": "ஒரு மொழியைச் சேர்க்கவும்…"
    }
}

for lang, filepath in files.items():
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        data.update(data_to_add[lang])
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

print("Settings buttons translations added successfully.")
