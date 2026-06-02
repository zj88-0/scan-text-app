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
        "home_no_saved_texts_guest": "Scan an image to get started.\nSign in to save your scans.",
        "home_search_by_name": "Search by name…",
        "home_daily_scans": "Daily Scans",
        "home_scans_left": "scans left today",
        "home_of": "of",
        "home_clear": "Clear",
        "home_close_search": "Close search",
        "home_no_results": "No results for",
        "home_result": "result for",
        "home_results": "results for",
        "home_no_named_entries": "No named entries match",
        "home_only_entries_with_name": "Only entries with a name are searched.\nTap the ✎ icon on a card to add a name."
    },
    'zh': {
        "home_no_saved_texts_guest": "扫描图像开始。\n登录以保存您的扫描。",
        "home_search_by_name": "按名称搜索…",
        "home_daily_scans": "每日扫描",
        "home_scans_left": "次扫描剩余",
        "home_of": "/",
        "home_clear": "清除",
        "home_close_search": "关闭搜索",
        "home_no_results": "没有结果：",
        "home_result": "个结果：",
        "home_results": "个结果：",
        "home_no_named_entries": "没有命名的条目匹配",
        "home_only_entries_with_name": "仅搜索带名称的条目。\n点击卡片上的 ✎ 图标添加名称。"
    },
    'ms': {
        "home_no_saved_texts_guest": "Imbas imej untuk bermula.\nLog masuk untuk menyimpan imbasan anda.",
        "home_search_by_name": "Cari mengikut nama…",
        "home_daily_scans": "Imbasan Harian",
        "home_scans_left": "imbasan tinggal hari ini",
        "home_of": "daripada",
        "home_clear": "Kosongkan",
        "home_close_search": "Tutup carian",
        "home_no_results": "Tiada hasil untuk",
        "home_result": "hasil untuk",
        "home_results": "hasil untuk",
        "home_no_named_entries": "Tiada entri bernama yang sepadan",
        "home_only_entries_with_name": "Hanya entri dengan nama dicari.\nKetik ikon ✎ pada kad untuk menambah nama."
    },
    'ta': {
        "home_no_saved_texts_guest": "தொடங்க ஒரு படத்தைய ஸ்கேன் செய்யவும்.\nஉங்கள் ஸ்கேன்களைச் சேமிக்க உள்நுழையவும்.",
        "home_search_by_name": "பெயர் மூலம் தேடுக…",
        "home_daily_scans": "தினசரி ஸ்கேன்கள்",
        "home_scans_left": "இன்று மீதமுள்ள ஸ்கேன்கள்",
        "home_of": "/",
        "home_clear": "அழி",
        "home_close_search": "தேடலை மூடு",
        "home_no_results": "முடிவுகள் இல்லை:",
        "home_result": "முடிவு:",
        "home_results": "முடிவுகள்:",
        "home_no_named_entries": "பெயரிடப்பட்ட உள்ளீடுகள் பொருந்தவில்லை",
        "home_only_entries_with_name": "பெயரைக் கொண்ட உள்ளீடுகள் மட்டுமே தேடப்படுகின்றன.\nபெயரைச் சேர்க்க அட்டையில் உள்ள ✎ ஐகானைத் தட்டவும்."
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
