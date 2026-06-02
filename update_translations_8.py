import json
import os

files = {
    'en': 'assets/translations/en.json',
    'zh': 'assets/translations/zh.json',
    'ms': 'assets/translations/ms.json',
    'ta': 'assets/translations/ta.json'
}

translations = {
    'en': {
        'voice_loading_title': 'Loading available voices…',
        'voice_loading_desc': 'Fetching voices from your device\nand preparing translations.'
    },
    'zh': {
        'voice_loading_title': '正在加载可用声音…',
        'voice_loading_desc': '正在从您的设备获取声音\n并准备翻译。'
    },
    'ms': {
        'voice_loading_title': 'Memuatkan suara yang tersedia…',
        'voice_loading_desc': 'Mendapatkan suara daripada peranti anda\ndan menyediakan terjemahan.'
    },
    'ta': {
        'voice_loading_title': 'கிடைக்கக்கூடிய குரல்களை ஏற்றுகிறது…',
        'voice_loading_desc': 'உங்கள் சாதனத்திலிருந்து குரல்களைப் பெறுகிறது\nமற்றும் மொழிபெயர்ப்புகளைத் தயாரிக்கிறது.'
    }
}

for lang, filepath in files.items():
    if not os.path.exists(filepath):
        continue
        
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    for key, val in translations[lang].items():
        data[key] = val
        
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Updated {filepath}")
