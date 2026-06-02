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
        'login_err_empty_email': 'Please enter your email',
        'login_err_invalid_email': 'Please enter a valid email',
        'login_err_empty_pass': 'Please enter your password',
        'login_err_user_not_found': 'No account found for that email.',
        'login_err_wrong_pass': 'Incorrect password. Please try again.',
        'login_err_disabled': 'This account has been disabled.',
        'login_err_too_many': 'Too many attempts. Try again later.',
        'login_err_failed': 'Sign-in failed. Please try again.',
        'login_err_generic': 'Something went wrong. Please try again.',
        'login_err_guest': 'Could not start as Guest. Please try again.',
        'verify_desc_1': 'We sent a verification link to',
        'verify_desc_2': 'Open the link in that email, then tap the button below.',
        'verify_err_not_yet': 'Email not verified yet. Please click the link in your inbox first.',
        'verify_msg_resent': 'Verification email resent.',
        'setup_checking_models': 'Checking language models…',
        'setup_waiting_wifi': 'Waiting for Wi-Fi...\n(Will auto-resume when connected)',
        'setup_switching_wifi': 'Switching to Wi-Fi...\nRestarting download for faster speed.',
        'setup_downloaded': 'Downloaded',
        'setup_of': 'of'
    },
    'zh': {
        'login_err_empty_email': '请输入您的电子邮件',
        'login_err_invalid_email': '请输入有效的电子邮件',
        'login_err_empty_pass': '请输入您的密码',
        'login_err_user_not_found': '找不到该电子邮件对应的账号。',
        'login_err_wrong_pass': '密码错误，请重试。',
        'login_err_disabled': '此账号已被禁用。',
        'login_err_too_many': '尝试次数过多。请稍后再试。',
        'login_err_failed': '登录失败，请重试。',
        'login_err_generic': '出现错误，请重试。',
        'login_err_guest': '无法以访客身份启动，请重试。',
        'verify_desc_1': '我们发送了一封验证链接到',
        'verify_desc_2': '打开电子邮件中的链接，然后点击下方的按钮。',
        'verify_err_not_yet': '电子邮件尚未验证。请先点击收件箱中的链接。',
        'verify_msg_resent': '已重新发送验证电子邮件。',
        'setup_checking_models': '正在检查语言模型…',
        'setup_waiting_wifi': '正在等待 Wi-Fi...\n（连接后将自动恢复）',
        'setup_switching_wifi': '正在切换到 Wi-Fi...\n重新启动下载以提高速度。',
        'setup_downloaded': '已下载',
        'setup_of': '/'
    },
    'ms': {
        'login_err_empty_email': 'Sila masukkan e-mel anda',
        'login_err_invalid_email': 'Sila masukkan e-mel yang sah',
        'login_err_empty_pass': 'Sila masukkan kata laluan anda',
        'login_err_user_not_found': 'Tiada akaun ditemui untuk e-mel tersebut.',
        'login_err_wrong_pass': 'Kata laluan salah. Sila cuba lagi.',
        'login_err_disabled': 'Akaun ini telah dilumpuhkan.',
        'login_err_too_many': 'Terlalu banyak percubaan. Cuba lagi nanti.',
        'login_err_failed': 'Gagal log masuk. Sila cuba lagi.',
        'login_err_generic': 'Sesuatu tidak kena. Sila cuba lagi.',
        'login_err_guest': 'Tidak dapat bermula sebagai Tetamu. Sila cuba lagi.',
        'verify_desc_1': 'Kami menghantar pautan pengesahan ke',
        'verify_desc_2': 'Buka pautan dalam e-mel tersebut, kemudian ketik butang di bawah.',
        'verify_err_not_yet': 'E-mel belum disahkan. Sila klik pautan dalam peti masuk anda dahulu.',
        'verify_msg_resent': 'E-mel pengesahan dihantar semula.',
        'setup_checking_models': 'Menyemak model bahasa…',
        'setup_waiting_wifi': 'Menunggu Wi-Fi...\n(Akan disambung semula apabila disambungkan)',
        'setup_switching_wifi': 'Bertukar kepada Wi-Fi...\nMemulakan semula muat turun untuk kelajuan yang lebih pantas.',
        'setup_downloaded': 'Dimuat turun',
        'setup_of': 'daripada'
    },
    'ta': {
        'login_err_empty_email': 'உங்கள் மின்னஞ்சலை உள்ளிடவும்',
        'login_err_invalid_email': 'சரியான மின்னஞ்சலை உள்ளிடவும்',
        'login_err_empty_pass': 'உங்கள் கடவுச்சொல்லை உள்ளிடவும்',
        'login_err_user_not_found': 'அந்த மின்னஞ்சலுக்கு எந்த கணக்கும் கிடைக்கவில்லை.',
        'login_err_wrong_pass': 'தவறான கடவுச்சொல். மீண்டும் முயற்சிக்கவும்.',
        'login_err_disabled': 'இந்த கணக்கு முடக்கப்பட்டுள்ளது.',
        'login_err_too_many': 'பல முயற்சிகள். பிறகு முயற்சிக்கவும்.',
        'login_err_failed': 'உள்நுழைவு தோல்வியடைந்தது. மீண்டும் முயற்சிக்கவும்.',
        'login_err_generic': 'ஏதோ தவறு நடந்துவிட்டது. மீண்டும் முயற்சிக்கவும்.',
        'login_err_guest': 'விருந்தினராக தொடங்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
        'verify_desc_1': 'இதற்கு ஒரு சரிபார்ப்பு இணைப்பை அனுப்பியுள்ளோம்',
        'verify_desc_2': 'அந்த மின்னஞ்சலில் உள்ள இணைப்பைத் திறந்து, கீழே உள்ள பொத்தானைத் தட்டவும்.',
        'verify_err_not_yet': 'மின்னஞ்சல் இன்னும் சரிபார்க்கப்படவில்லை. முதலில் உங்கள் இன்பாக்ஸில் உள்ள இணைப்பைக் கிளிக் செய்யவும்.',
        'verify_msg_resent': 'சரிபார்ப்பு மின்னஞ்சல் மீண்டும் அனுப்பப்பட்டது.',
        'setup_checking_models': 'மொழி மாதிரிகளை சரிபார்க்கிறது…',
        'setup_waiting_wifi': 'Wi-Fi-க்காக காத்திருக்கிறது...\n(இணைக்கப்பட்டதும் தானாகவே தொடரும்)',
        'setup_switching_wifi': 'Wi-Fi-க்கு மாறுகிறது...\nவேகத்திற்காக பதிவிறக்கத்தை மீண்டும் தொடங்குகிறது.',
        'setup_downloaded': 'பதிவிறக்கப்பட்டது',
        'setup_of': '/'
    }
}

for lang, filepath in files.items():
    if not os.path.exists(filepath):
        continue
        
    with open(filepath, 'r', encoding='utf-8') as f:
        data = json.load(f)
        
    # Update data
    for key, val in translations[lang].items():
        data[key] = val
        
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"Updated {filepath}")
