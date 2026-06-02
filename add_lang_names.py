import json, os

# Language names translated into each supported app language
translations = {
    'en': {
        'af': 'Afrikaans', 'ar': 'Arabic', 'be': 'Belarusian', 'bg': 'Bulgarian',
        'bn': 'Bengali', 'ca': 'Catalan', 'cs': 'Czech', 'cy': 'Welsh',
        'da': 'Danish', 'de': 'German', 'el': 'Greek', 'en': 'English',
        'eo': 'Esperanto', 'es': 'Spanish', 'et': 'Estonian', 'fa': 'Persian',
        'fi': 'Finnish', 'fr': 'French', 'ga': 'Irish', 'gl': 'Galician',
        'gu': 'Gujarati', 'he': 'Hebrew', 'hi': 'Hindi', 'hr': 'Croatian',
        'ht': 'Haitian Creole', 'hu': 'Hungarian', 'id': 'Indonesian',
        'is': 'Icelandic', 'it': 'Italian', 'ja': 'Japanese', 'ka': 'Georgian',
        'kn': 'Kannada', 'ko': 'Korean', 'lt': 'Lithuanian', 'lv': 'Latvian',
        'mk': 'Macedonian', 'mr': 'Marathi', 'ms': 'Malay', 'mt': 'Maltese',
        'nl': 'Dutch', 'no': 'Norwegian', 'pl': 'Polish', 'pt': 'Portuguese',
        'ro': 'Romanian', 'ru': 'Russian', 'sk': 'Slovak', 'sl': 'Slovenian',
        'sq': 'Albanian', 'sr': 'Serbian', 'sv': 'Swedish', 'sw': 'Swahili',
        'ta': 'Tamil', 'te': 'Telugu', 'th': 'Thai', 'tl': 'Filipino',
        'tr': 'Turkish', 'uk': 'Ukrainian', 'ur': 'Urdu', 'vi': 'Vietnamese',
        'zh': 'Chinese',
    },
    'zh': {
        'af': '南非荷兰语', 'ar': '阿拉伯语', 'be': '白俄罗斯语', 'bg': '保加利亚语',
        'bn': '孟加拉语', 'ca': '加泰罗尼亚语', 'cs': '捷克语', 'cy': '威尔士语',
        'da': '丹麦语', 'de': '德语', 'el': '希腊语', 'en': '英语',
        'eo': '世界语', 'es': '西班牙语', 'et': '爱沙尼亚语', 'fa': '波斯语',
        'fi': '芬兰语', 'fr': '法语', 'ga': '爱尔兰语', 'gl': '加利西亚语',
        'gu': '古吉拉特语', 'he': '希伯来语', 'hi': '印地语', 'hr': '克罗地亚语',
        'ht': '海地克里奥尔语', 'hu': '匈牙利语', 'id': '印度尼西亚语',
        'is': '冰岛语', 'it': '意大利语', 'ja': '日语', 'ka': '格鲁吉亚语',
        'kn': '卡纳达语', 'ko': '韩语', 'lt': '立陶宛语', 'lv': '拉脱维亚语',
        'mk': '马其顿语', 'mr': '马拉地语', 'ms': '马来语', 'mt': '马耳他语',
        'nl': '荷兰语', 'no': '挪威语', 'pl': '波兰语', 'pt': '葡萄牙语',
        'ro': '罗马尼亚语', 'ru': '俄语', 'sk': '斯洛伐克语', 'sl': '斯洛文尼亚语',
        'sq': '阿尔巴尼亚语', 'sr': '塞尔维亚语', 'sv': '瑞典语', 'sw': '斯瓦希里语',
        'ta': '泰米尔语', 'te': '泰卢固语', 'th': '泰语', 'tl': '菲律宾语',
        'tr': '土耳其语', 'uk': '乌克兰语', 'ur': '乌尔都语', 'vi': '越南语',
        'zh': '中文',
    },
    'ms': {
        'af': 'Afrikaans', 'ar': 'Arab', 'be': 'Belarus', 'bg': 'Bulgaria',
        'bn': 'Bengali', 'ca': 'Catalan', 'cs': 'Czech', 'cy': 'Wales',
        'da': 'Denmark', 'de': 'Jerman', 'el': 'Greek', 'en': 'Inggeris',
        'eo': 'Esperanto', 'es': 'Sepanyol', 'et': 'Estonia', 'fa': 'Parsi',
        'fi': 'Finland', 'fr': 'Perancis', 'ga': 'Ireland', 'gl': 'Galicia',
        'gu': 'Gujarati', 'he': 'Ibrani', 'hi': 'Hindi', 'hr': 'Croatia',
        'ht': 'Kreol Haiti', 'hu': 'Hungary', 'id': 'Indonesia',
        'is': 'Iceland', 'it': 'Itali', 'ja': 'Jepun', 'ka': 'Georgia',
        'kn': 'Kannada', 'ko': 'Korea', 'lt': 'Lithuania', 'lv': 'Latvia',
        'mk': 'Macedonia', 'mr': 'Marathi', 'ms': 'Melayu', 'mt': 'Malta',
        'nl': 'Belanda', 'no': 'Norway', 'pl': 'Poland', 'pt': 'Portugis',
        'ro': 'Romania', 'ru': 'Rusia', 'sk': 'Slovak', 'sl': 'Slovenia',
        'sq': 'Albania', 'sr': 'Serbia', 'sv': 'Sweden', 'sw': 'Swahili',
        'ta': 'Tamil', 'te': 'Telugu', 'th': 'Thai', 'tl': 'Filipino',
        'tr': 'Turki', 'uk': 'Ukraine', 'ur': 'Urdu', 'vi': 'Vietnam',
        'zh': 'Cina',
    },
    'ta': {
        'af': 'ஆஃப்ரிகான்ஸ்', 'ar': 'அரபிக்', 'be': 'பெலாரஷியன்', 'bg': 'பல்கேரியன்',
        'bn': 'பெங்காலி', 'ca': 'கட்டாலன்', 'cs': 'செக்', 'cy': 'வெல்ஷ்',
        'da': 'டேனிஷ்', 'de': 'ஜெர்மன்', 'el': 'கிரேக்கம்', 'en': 'ஆங்கிலம்',
        'eo': 'எஸ்பரான்டோ', 'es': 'ஸ்பானிஷ்', 'et': 'எஸ்டோனியன்', 'fa': 'பாரசீகம்',
        'fi': 'ஃபின்னிஷ்', 'fr': 'பிரெஞ்சு', 'ga': 'ஐரிஷ்', 'gl': 'கலீசியன்',
        'gu': 'குஜராத்தி', 'he': 'ஹீப்ரு', 'hi': 'இந்தி', 'hr': 'குரோஷியன்',
        'ht': 'ஹைட்டியன் கிரியோல்', 'hu': 'ஹங்கேரியன்', 'id': 'இந்தோனேசியன்',
        'is': 'ஐஸ்லாண்டிக்', 'it': 'இத்தாலியன்', 'ja': 'ஜப்பானீஸ்', 'ka': 'ஜார்ஜியன்',
        'kn': 'கன்னடம்', 'ko': 'கொரியன்', 'lt': 'லிதுவேனியன்', 'lv': 'லாட்வியன்',
        'mk': 'மாசிடோனியன்', 'mr': 'மராத்தி', 'ms': 'மலாய்', 'mt': 'மால்டீஸ்',
        'nl': 'டச்சு', 'no': 'நார்வீஜியன்', 'pl': 'போலிஷ்', 'pt': 'போர்த்துகீஸ்',
        'ro': 'ருமேனியன்', 'ru': 'ரஷியன்', 'sk': 'ஸ்லோவாக்', 'sl': 'ஸ்லோவேனியன்',
        'sq': 'அல்பேனியன்', 'sr': 'சேர்பியன்', 'sv': 'ஸ்வீடிஷ்', 'sw': 'ஸ்வாஹிலி',
        'ta': 'தமிழ்', 'te': 'தெலுங்கு', 'th': 'தாய்', 'tl': 'ஃபிலிபினோ',
        'tr': 'துர்க்கிஷ்', 'uk': 'உக்ரேனியன்', 'ur': 'உர்து', 'vi': 'வியட்நாமீஸ்',
        'zh': 'சீனம்',
    },
}

base = r'assets\translations'
for lang_code, names in translations.items():
    path = os.path.join(base, f'{lang_code}.json')
    with open(path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    for code, name in names.items():
        data[f'lang_name_{code}'] = name
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    print(f'Updated {path}')

print('Done.')
