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
        "home_tap_to_read": "Tap to read",
        "home_add_name": "Add name",
        "home_edit_name": "Edit name"
    },
    'zh': {
        "home_tap_to_read": "点击阅读",
        "home_add_name": "添加名称",
        "home_edit_name": "编辑名称"
    },
    'ms': {
        "home_tap_to_read": "Ketik untuk membaca",
        "home_add_name": "Tambah nama",
        "home_edit_name": "Edit nama"
    },
    'ta': {
        "home_tap_to_read": "படிக்க தட்டவும்",
        "home_add_name": "பெயரைச் சேர்",
        "home_edit_name": "பெயரைத் திருத்து"
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
