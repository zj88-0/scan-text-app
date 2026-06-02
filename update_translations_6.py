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
        'signup_err_in_use': 'An account already exists for that email.',
        'signup_err_weak_pass': 'Password is too weak. Use at least 6 characters.',
        'signup_err_failed': 'Sign-up failed. Please try again.',
        'signup_title': 'Create Account',
        'signup_subtitle': 'Sign up to get started',
        'signup_confirm_pass': 'Confirm Password',
        'signup_err_confirm': 'Please confirm your password',
        'signup_err_match': 'Passwords do not match',
        'signup_already': 'Already have an account?',
        'signup_check_email': 'Check Your Email',
        'signup_check_desc_1': 'Tap the link in that email, then come back\nand press the button below.',
        'signup_resend': 'Resend Verification Email',
        'signup_resend_in': 'Resend in',
        'signup_btn_create': 'Create Account',
        
        'forgot_title': 'Reset Password',
        'forgot_subtitle': 'Enter your email to receive a password reset link.',
        'forgot_btn': 'Send Reset Link',
        'forgot_success': 'Password reset link sent! Check your email.',
        'forgot_err_failed': 'Failed to send reset link. Please try again.',
        'forgot_back': 'Back to Sign In'
    },
    'zh': {
        'signup_err_in_use': '该电子邮件已存在账号。',
        'signup_err_weak_pass': '密码太弱。请至少使用 6 个字符。',
        'signup_err_failed': '注册失败，请重试。',
        'signup_title': '创建账号',
        'signup_subtitle': '注册以开始使用',
        'signup_confirm_pass': '确认密码',
        'signup_err_confirm': '请确认您的密码',
        'signup_err_match': '两次输入的密码不一致',
        'signup_already': '已有账号？',
        'signup_check_email': '检查您的电子邮件',
        'signup_check_desc_1': '点击该电子邮件中的链接，然后返回\n并按下方按钮。',
        'signup_resend': '重新发送验证电子邮件',
        'signup_resend_in': '重新发送剩余时间',
        'signup_btn_create': '创建账号',

        'forgot_title': '重置密码',
        'forgot_subtitle': '输入您的电子邮件以接收密码重置链接。',
        'forgot_btn': '发送重置链接',
        'forgot_success': '密码重置链接已发送！请检查您的电子邮件。',
        'forgot_err_failed': '发送重置链接失败，请重试。',
        'forgot_back': '返回登录'
    },
    'ms': {
        'signup_err_in_use': 'Akaun sudah wujud untuk e-mel tersebut.',
        'signup_err_weak_pass': 'Kata laluan terlalu lemah. Guna sekurang-kurangnya 6 aksara.',
        'signup_err_failed': 'Gagal mendaftar. Sila cuba lagi.',
        'signup_title': 'Cipta Akaun',
        'signup_subtitle': 'Daftar untuk bermula',
        'signup_confirm_pass': 'Sahkan Kata Laluan',
        'signup_err_confirm': 'Sila sahkan kata laluan anda',
        'signup_err_match': 'Kata laluan tidak sepadan',
        'signup_already': 'Sudah mempunyai akaun?',
        'signup_check_email': 'Semak E-mel Anda',
        'signup_check_desc_1': 'Ketik pautan dalam e-mel tersebut, kemudian kembali\ndan tekan butang di bawah.',
        'signup_resend': 'Hantar Semula E-mel Pengesahan',
        'signup_resend_in': 'Hantar semula dalam',
        'signup_btn_create': 'Cipta Akaun',

        'forgot_title': 'Tetapkan Semula Kata Laluan',
        'forgot_subtitle': 'Masukkan e-mel anda untuk menerima pautan tetapan semula kata laluan.',
        'forgot_btn': 'Hantar Pautan',
        'forgot_success': 'Pautan tetapan semula dihantar! Semak e-mel anda.',
        'forgot_err_failed': 'Gagal menghantar pautan. Sila cuba lagi.',
        'forgot_back': 'Kembali ke Log Masuk'
    },
    'ta': {
        'signup_err_in_use': 'அந்த மின்னஞ்சலுக்கு ஏற்கனவே ஒரு கணக்கு உள்ளது.',
        'signup_err_weak_pass': 'கடவுச்சொல் மிகவும் பலவீனமாக உள்ளது. குறைந்தது 6 எழுத்துகளைப் பயன்படுத்தவும்.',
        'signup_err_failed': 'பதிவு தோல்வியடைந்தது. மீண்டும் முயற்சிக்கவும்.',
        'signup_title': 'கணக்கை உருவாக்கவும்',
        'signup_subtitle': 'தொடங்க பதிவு செய்யவும்',
        'signup_confirm_pass': 'கடவுச்சொல்லை உறுதிப்படுத்தவும்',
        'signup_err_confirm': 'உங்கள் கடவுச்சொல்லை உறுதிப்படுத்தவும்',
        'signup_err_match': 'கடவுச்சொற்கள் பொருந்தவில்லை',
        'signup_already': 'ஏற்கனவே கணக்கு உள்ளதா?',
        'signup_check_email': 'உங்கள் மின்னஞ்சலை சரிபார்க்கவும்',
        'signup_check_desc_1': 'அந்த மின்னஞ்சலில் உள்ள இணைப்பைத் தட்டி, பின்னர் திரும்பி வந்து கீழே உள்ள பொத்தானை அழுத்தவும்.',
        'signup_resend': 'சரிபார்ப்பு மின்னஞ்சலை மீண்டும் அனுப்பவும்',
        'signup_resend_in': 'மீண்டும் அனுப்ப வேண்டிய நேரம்',
        'signup_btn_create': 'கணக்கை உருவாக்கவும்',

        'forgot_title': 'கடவுச்சொல்லை மீட்டமைக்கவும்',
        'forgot_subtitle': 'உங்கள் கடவுச்சொல்லை மீட்டமைப்பதற்கான இணைப்பைப் பெற மின்னஞ்சலை உள்ளிடவும்.',
        'forgot_btn': 'இணைப்பை அனுப்பவும்',
        'forgot_success': 'மீட்டமைப்பதற்கான இணைப்பு அனுப்பப்பட்டது! உங்கள் மின்னஞ்சலை சரிபார்க்கவும்.',
        'forgot_err_failed': 'இணைப்பை அனுப்ப முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
        'forgot_back': 'உள்நுழைவிற்குத் திரும்புக'
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
