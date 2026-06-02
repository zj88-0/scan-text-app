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
        "upgrade_standard": "Standard",
        "upgrade_standard_sub": "On-device translation",
        "upgrade_std_feat_1": "Instant translation for all languages",
        "upgrade_std_feat_2": "Direct word-for-word translation",
        "upgrade_std_feat_3": "3 scans per day",
        "upgrade_switched_std": "Switched to Standard tier.",
        "upgrade_switch_std_btn": "Switch to Standard",
        "upgrade_active": "Active",
        "upgrade_premium": "Premium",
        "upgrade_premium_sub": "AI translation · Natural & context-aware",
        "upgrade_prem_feat_1": "Natural, fluent translations",
        "upgrade_prem_feat_2": "Names & abbreviations handled intelligently",
        "upgrade_prem_feat_3": "Results cached locally",
        "upgrade_prem_feat_4": "Unlimited scans",
        "upgrade_switched_prem": "Switched to Premium AI translation!",
        "upgrade_switch_prem_btn": "Switch to Premium"
    },
    'zh': {
        "upgrade_standard": "标准",
        "upgrade_standard_sub": "设备端翻译",
        "upgrade_std_feat_1": "所有语言即时翻译",
        "upgrade_std_feat_2": "直接逐字翻译",
        "upgrade_std_feat_3": "每天 3 次扫描",
        "upgrade_switched_std": "已切换到标准层级。",
        "upgrade_switch_std_btn": "切换到标准版",
        "upgrade_active": "使用中",
        "upgrade_premium": "高级",
        "upgrade_premium_sub": "AI 翻译 · 自然且符合语境",
        "upgrade_prem_feat_1": "自然流畅的翻译",
        "upgrade_prem_feat_2": "智能处理名称和缩写",
        "upgrade_prem_feat_3": "结果在本地缓存",
        "upgrade_prem_feat_4": "无限扫描",
        "upgrade_switched_prem": "已切换到高级 AI 翻译！",
        "upgrade_switch_prem_btn": "切换到高级版"
    },
    'ms': {
        "upgrade_standard": "Standard",
        "upgrade_standard_sub": "Terjemahan pada peranti",
        "upgrade_std_feat_1": "Terjemahan segera untuk semua bahasa",
        "upgrade_std_feat_2": "Terjemahan terus kata demi kata",
        "upgrade_std_feat_3": "3 imbasan sehari",
        "upgrade_switched_std": "Bertukar ke peringkat Standard.",
        "upgrade_switch_std_btn": "Tukar ke Standard",
        "upgrade_active": "Aktif",
        "upgrade_premium": "Premium",
        "upgrade_premium_sub": "Terjemahan AI · Semula jadi & peka konteks",
        "upgrade_prem_feat_1": "Terjemahan lancar dan semula jadi",
        "upgrade_prem_feat_2": "Nama & singkatan dikendalikan secara bijak",
        "upgrade_prem_feat_3": "Keputusan disimpan secara tempatan",
        "upgrade_prem_feat_4": "Imbasan tanpa had",
        "upgrade_switched_prem": "Bertukar ke terjemahan AI Premium!",
        "upgrade_switch_prem_btn": "Tukar ke Premium"
    },
    'ta': {
        "upgrade_standard": "நிலையான",
        "upgrade_standard_sub": "சாதனத்தில் மொழிபெயர்ப்பு",
        "upgrade_std_feat_1": "அனைத்து மொழிகளுக்கும் உடனடி மொழிபெயர்ப்பு",
        "upgrade_std_feat_2": "நேரடி வார்த்தைக்கு வார்த்தை மொழிபெயர்ப்பு",
        "upgrade_std_feat_3": "ஒரு நாளைக்கு 3 ஸ்கேன்கள்",
        "upgrade_switched_std": "நிலையான அடுக்குக்கு மாற்றப்பட்டது.",
        "upgrade_switch_std_btn": "நிலையானதற்கு மாறவும்",
        "upgrade_active": "செயலில்",
        "upgrade_premium": "பிரீமியம்",
        "upgrade_premium_sub": "AI மொழிபெயர்ப்பு · இயற்கை மற்றும் சூழல் சார்ந்தது",
        "upgrade_prem_feat_1": "இயற்கையான, சரளமான மொழிபெயர்ப்புகள்",
        "upgrade_prem_feat_2": "பெயர்கள் மற்றும் சுருக்கங்கள் புத்திசாலித்தனமாக கையாளப்படுகின்றன",
        "upgrade_prem_feat_3": "முடிவுகள் உள்நாட்டில் சேமிக்கப்பட்டன",
        "upgrade_prem_feat_4": "வரம்பற்ற ஸ்கேன்கள்",
        "upgrade_switched_prem": "பிரீமியம் AI மொழிபெயர்ப்புக்கு மாற்றப்பட்டது!",
        "upgrade_switch_prem_btn": "பிரீமியத்திற்கு மாறவும்"
    }
}

for lang, filepath in files.items():
    if os.path.exists(filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            data = json.load(f)
        data.update(data_to_add[lang])
        with open(filepath, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

print("Upgrade translations added successfully.")
