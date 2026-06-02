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
        'login_continue_as_guest': 'Continue as Guest',
        'login_email_address': 'Email Address',
        'login_password': 'Password',
        'login_forgot_password': 'Forgot Password?',
        'login_sign_in': 'Sign In',
        'login_or_continue_with': 'or continue with',
        'login_continue_with_google': 'Continue with Google',
        'login_no_account': "Don't have an account?",
        'login_sign_up': 'Sign Up',
        'verify_title': 'Verify Your Email',
        'verify_checking': 'Checking automatically…',
        'verify_btn_check': 'Checking…',
        'verify_btn_continue': "I've Verified — Continue",
        'verify_resend': 'Resend Email',
        'verify_diff_account': 'Use a different account',
        'setup_checking_conn': 'Checking your connection…',
        'setup_downloading': 'Downloading translation models.\nThis only happens once.',
        'setup_setting_up': 'Setting up translation…',
        'setup_all_set': 'All set! Starting app…'
    },
    'zh': {
        'login_continue_as_guest': '点击使用',
        'login_email_address': '电子邮件地址',
        'login_password': '密码',
        'login_forgot_password': '忘记密码？',
        'login_sign_in': '登录',
        'login_or_continue_with': '或使用以下方式继续',
        'login_continue_with_google': '使用 Google 账号继续',
        'login_no_account': "没有账号？",
        'login_sign_up': '注册',
        'verify_title': '验证您的电子邮件',
        'verify_checking': '自动检查中…',
        'verify_btn_check': '检查中…',
        'verify_btn_continue': "我已验证 — 继续",
        'verify_resend': '重新发送电子邮件',
        'verify_diff_account': '使用其他账号',
        'setup_checking_conn': '正在检查网络连接…',
        'setup_downloading': '正在下载翻译模型。\n这只需要进行一次。',
        'setup_setting_up': '正在设置翻译…',
        'setup_all_set': '设置完成！正在启动应用…'
    },
    'ms': {
        'login_continue_as_guest': 'Klik untuk guna',
        'login_email_address': 'Alamat E-mel',
        'login_password': 'Kata Laluan',
        'login_forgot_password': 'Lupa Kata Laluan?',
        'login_sign_in': 'Log Masuk',
        'login_or_continue_with': 'atau teruskan dengan',
        'login_continue_with_google': 'Teruskan dengan Google',
        'login_no_account': "Tiada akaun?",
        'login_sign_up': 'Daftar',
        'verify_title': 'Sahkan E-mel Anda',
        'verify_checking': 'Menyemak secara automatik…',
        'verify_btn_check': 'Menyemak…',
        'verify_btn_continue': "Saya Telah Sahkan — Teruskan",
        'verify_resend': 'Hantar Semula E-mel',
        'verify_diff_account': 'Guna akaun lain',
        'setup_checking_conn': 'Menyemak sambungan anda…',
        'setup_downloading': 'Memuat turun model terjemahan.\nIni hanya berlaku sekali.',
        'setup_setting_up': 'Menetapkan terjemahan…',
        'setup_all_set': 'Semua sedia! Memulakan aplikasi…'
    },
    'ta': {
        'login_continue_as_guest': 'பயன்படுத்த கிளிக் செய்யவும்',
        'login_email_address': 'மின்னஞ்சல் முகவரி',
        'login_password': 'கடவுச்சொல்',
        'login_forgot_password': 'கடவுச்சொல் மறந்துவிட்டதா?',
        'login_sign_in': 'உள்நுழைக',
        'login_or_continue_with': 'அல்லது தொடரவும்',
        'login_continue_with_google': 'Google உடன் தொடரவும்',
        'login_no_account': "கணக்கு இல்லையா?",
        'login_sign_up': 'பதிவு செய்க',
        'verify_title': 'உங்கள் மின்னஞ்சலை சரிபார்க்கவும்',
        'verify_checking': 'தானாகவே சரிபார்க்கிறது…',
        'verify_btn_check': 'சரிபார்க்கிறது…',
        'verify_btn_continue': "நான் சரிபார்த்துள்ளேன் — தொடரவும்",
        'verify_resend': 'மின்னஞ்சலை மீண்டும் அனுப்பவும்',
        'verify_diff_account': 'வேறு கணக்கை பயன்படுத்தவும்',
        'setup_checking_conn': 'உங்கள் இணைப்பை சரிபார்க்கிறது…',
        'setup_downloading': 'மொழிபெயர்ப்பு மாதிரிகளைப் பதிவிறக்குகிறது.\nஇது ஒரு முறை மட்டுமே நடக்கும்.',
        'setup_setting_up': 'மொழிபெயர்ப்பை அமைக்கிறது…',
        'setup_all_set': 'எல்லாம் தயார்! பயன்பாட்டைத் தொடங்குகிறது…'
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
