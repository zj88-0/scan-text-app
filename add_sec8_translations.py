import json
import os

translations = {
    'en': {
        'terms_sec8_title': 'Copyright and Commercial Use',
        'terms_sec8_body': 'You may not use the translated text produced by this application for commercial purposes or in any way that violates copyright laws.'
    },
    'zh': {
        'terms_sec8_title': '版权与商业使用',
        'terms_sec8_body': '您不得将本应用程序生成的翻译文本用于商业用途或以任何违反版权法的方式使用。'
    },
    'ms': {
        'terms_sec8_title': 'Hak Cipta dan Penggunaan Komersial',
        'terms_sec8_body': 'Anda tidak boleh menggunakan teks terjemahan yang dihasilkan oleh aplikasi ini untuk tujuan komersial atau dengan cara apa pun yang melanggar undang-undang hak cipta.'
    },
    'ta': {
        'terms_sec8_title': 'பதிப்புரிமை மற்றும் வணிக பயன்பாடு',
        'terms_sec8_body': 'இந்த பயன்பாட்டால் உருவாக்கப்பட்ட மொழிபெயர்க்கப்பட்ட உரையை வணிக நோக்கங்களுக்காகவோ அல்லது பதிப்புரிமைச் சட்டங்களை மீறும் வகையிலோ நீங்கள் பயன்படுத்தக்கூடாது.'
    }
}

assets_dir = r"c:\SP\sp 2b\MAD\code\text_scanner\assets\translations"

for lang, new_data in translations.items():
    file_path = os.path.join(assets_dir, f"{lang}.json")
    if os.path.exists(file_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            
        data.update(new_data)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Updated {lang}.json")
