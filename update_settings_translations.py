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
        "settings_daily_scans": "Daily Scans",
        "settings_translation_languages": "Translation Languages",
        "settings_lang_desc": "Select up to 4 languages to show in the app. Models are stored on your device.",
        "settings_active": "active",
        "settings_account": "Account",
        "settings_unlimited": "Unlimited Scans",
        "settings_premium_plan": "Premium plan — no daily limit",
        "settings_free_plan_reset": "Resets at midnight • Free plan",
        "settings_used": "used",
        "settings_total": "total",
        "settings_loading": "Loading settings…"
    },
    'zh': {
        "settings_daily_scans": "每日扫描",
        "settings_translation_languages": "翻译语言",
        "settings_lang_desc": "最多选择 4 种语言在应用中显示。模型存储在您的设备上。",
        "settings_active": "已启用",
        "settings_account": "账户",
        "settings_unlimited": "无限扫描",
        "settings_premium_plan": "高级计划 — 无每日限制",
        "settings_free_plan_reset": "午夜重置 • 免费计划",
        "settings_used": "已使用",
        "settings_total": "总计",
        "settings_loading": "正在加载设置…"
    },
    'ms': {
        "settings_daily_scans": "Imbasan Harian",
        "settings_translation_languages": "Bahasa Terjemahan",
        "settings_lang_desc": "Pilih sehingga 4 bahasa untuk ditunjukkan dalam apl. Model disimpan pada peranti anda.",
        "settings_active": "aktif",
        "settings_account": "Akaun",
        "settings_unlimited": "Imbasan Tanpa Had",
        "settings_premium_plan": "Pelan premium — tiada had harian",
        "settings_free_plan_reset": "Tetapkan semula pada tengah malam • Pelan percuma",
        "settings_used": "digunakan",
        "settings_total": "jumlah",
        "settings_loading": "Memuatkan tetapan…"
    },
    'ta': {
        "settings_daily_scans": "தினசரி ஸ்கேன்கள்",
        "settings_translation_languages": "மொழிபெயர்ப்பு மொழிகள்",
        "settings_lang_desc": "பயன்பாட்டில் காட்ட 4 மொழிகள் வரை தேர்வு செய்யவும். மாதிரிகள் உங்கள் சாதனத்தில் சேமிக்கப்படும்.",
        "settings_active": "செயலில் உள்ளது",
        "settings_account": "கணக்கு",
        "settings_unlimited": "வரம்பற்ற ஸ்கேன்கள்",
        "settings_premium_plan": "பிரீமியம் திட்டம் — தினசரி வரம்பு இல்லை",
        "settings_free_plan_reset": "நள்ளிரவில் மீட்டமைக்கப்படும் • இலவச திட்டம்",
        "settings_used": "பயன்படுத்தப்பட்டது",
        "settings_total": "மொத்தம்",
        "settings_loading": "அமைப்புகளை ஏற்றுகிறது…"
    }
}

for lang, filepath in files.items():
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        data.update(data_to_add[lang])
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

print("Settings strings added successfully.")
