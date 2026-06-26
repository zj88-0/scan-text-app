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
        "lang_select_title": "Select Language",
        "lang_download_prompt": "Language package not downloaded. Download now?",
        "lang_download": "Download",
        "lang_cancel": "Cancel",
        "zoom_label": "Zoom"
    },
    'zh': {
        "lang_select_title": "选择语言",
        "lang_download_prompt": "语言包未下载，是否立即下载？",
        "lang_download": "下载",
        "lang_cancel": "取消",
        "zoom_label": "缩放"
    },
    'ms': {
        "lang_select_title": "Pilih Bahasa",
        "lang_download_prompt": "Pakej bahasa belum dimuat turun. Muat turun sekarang?",
        "lang_download": "Muat turun",
        "lang_cancel": "Batal",
        "zoom_label": "Zum"
    },
    'ta': {
        "lang_select_title": "மொழியைத் தேர்ந்தெடுக்கவும்",
        "lang_download_prompt": "மொழித் தொகுப்பு பதிவிறக்கப்படவில்லை. இப்போது பதிவிறக்கவா?",
        "lang_download": "பதிவிறக்கு",
        "lang_cancel": "ரத்து செய்",
        "zoom_label": "பெரிதாக்கு"
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
