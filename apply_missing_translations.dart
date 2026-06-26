import 'dart:convert';
import 'dart:io';

void main() {
  final Map<String, Map<String, String>> updates = {
    'zh': {
      'start_scan': '开始扫描',
      'home_current_scan_mode': '当前扫描模式:',
      'home_scan_mode_ai': 'AI（使用每日限额）',
      'home_scan_mode_local': '本地（离线且免费）',
      'confirm': '确认',
      'feedback': '反馈',
      'disclaimer_title': '免责声明',
      'disclaimer_body': '请确认您拥有保存和使用此文本的必要权利或权限。\n\n继续操作即表示您确认您独自负责确保遵守任何适用的版权法。',
      'retake_photo': '重拍',
      'retry': '重试',
      'settings_auto_read': '自动朗读',
      'settings_auto_read_desc': '打开时自动朗读文本。',
      'settings_start_muted': '默认静音',
      'settings_start_muted_desc': '仅高亮显示文本，不发出声音。',
      'mute': '静音',
      'unmute': '取消静音',
      'muted': '已静音',
      'reload': '重新加载',
      'translating_ai': '正在使用 AI 翻译...',
      'lang_select_title': '选择语言',
      'lang_download_prompt': '语言包未下载。立即下载？',
      'lang_download': '下载',
      'lang_cancel': '取消',
      'lang_downloading': '正在下载语言包...',
      'lang_download_wait': '这可能需要一点时间，请稍候。',
      'lang_download_failed': '下载失败。请检查您的网络连接并重试。',
      'result_offline_banner': '无网络连接 · 正在使用离线翻译',
      'zoom_label': '缩放',
    },
    'ms': {
      'start_scan': 'Mula Mengimbas',
      'home_current_scan_mode': 'Mod Imbasan Semasa:',
      'home_scan_mode_ai': 'AI (Guna Had Harian)',
      'home_scan_mode_local': 'Tempatan (Luar Talian & Percuma)',
      'confirm': 'Sahkan',
      'feedback': 'Maklum Balas',
      'disclaimer_title': 'Penafian',
      'disclaimer_body': 'Sila sahkan bahawa anda mempunyai hak atau kebenaran yang diperlukan untuk menyimpan dan menggunakan teks ini.\n\nDengan meneruskan, anda mengakui bahawa anda bertanggungjawab sepenuhnya untuk memastikan pematuhan terhadap mana-mana undang-undang hak cipta yang berkenaan.',
      'retake_photo': 'Ambil Semula',
      'retry': 'Cuba Semula',
      'settings_auto_read': 'Baca Auto',
      'settings_auto_read_desc': 'Baca teks secara automatik apabila dibuka.',
      'settings_start_muted': 'Mula Senyap',
      'settings_start_muted_desc': 'Serlahkan teks tanpa bunyi.',
      'mute': 'Senyap',
      'unmute': 'Bunyikan',
      'muted': 'Disenyapkan',
      'reload': 'Muat Semula',
      'translating_ai': 'Sedang menterjemah dengan AI...',
      'lang_select_title': 'Pilih Bahasa',
      'lang_download_prompt': 'Pakej bahasa belum dimuat turun. Muat turun sekarang?',
      'lang_download': 'Muat Turun',
      'lang_cancel': 'Batal',
      'lang_downloading': 'Sedang memuat turun pakej bahasa...',
      'lang_download_wait': 'Ini mungkin mengambil masa. Sila tunggu.',
      'lang_download_failed': 'Muat turun gagal. Sila periksa sambungan anda dan cuba lagi.',
      'result_offline_banner': 'Tiada sambungan internet · Menggunakan terjemahan luar talian',
      'zoom_label': 'Zum',
    },
    'ta': {
      'start_scan': 'ஸ்கேன் செய்யத் தொடங்கு',
      'home_current_scan_mode': 'தற்போதைய ஸ்கேன் பயன்முறை:',
      'home_scan_mode_ai': 'AI (தினசரி வரம்பைப் பயன்படுத்துகிறது)',
      'home_scan_mode_local': 'உள்ளூர் (ஆஃப்லைன் & இலவசம்)',
      'confirm': 'உறுதிப்படுத்து',
      'feedback': 'கருத்து',
      'disclaimer_title': 'மறுப்பு',
      'disclaimer_body': 'இந்த உரையைச் சேமிக்கவும் பயன்படுத்தவும் உங்களுக்குத் தேவையான உரிமைகள் அல்லது அனுமதிகள் இருப்பதை உறுதிப்படுத்தவும்.\n\nதொடர்வதன் மூலம், பொருந்தக்கூடிய பதிப்புரிமைச் சட்டங்களுக்கு இணங்குவதை உறுதிசெய்வதற்கு நீங்கள் மட்டுமே பொறுப்பு என்பதை ஒப்புக்கொள்கிறீர்கள்.',
      'retake_photo': 'மீண்டும் எடுக்கவும்',
      'retry': 'மீண்டும் முயற்சிக்கவும்',
      'settings_auto_read': 'தானாகப் படி',
      'settings_auto_read_desc': 'திறக்கும்போது உரையைத் தானாகப் படிக்கவும்.',
      'settings_start_muted': 'முடக்கித் தொடங்கு',
      'settings_start_muted_desc': 'ஒலியின்றி உரையைத் தனிப்படுத்திக் காட்டவும்.',
      'mute': 'ஒலியை முடக்கு',
      'unmute': 'ஒலியை இயக்கு',
      'muted': 'முடக்கப்பட்டுள்ளது',
      'reload': 'மீண்டும் ஏற்றவும்',
      'translating_ai': 'AI மூலம் மொழிபெயர்க்கிறது...',
      'lang_select_title': 'மொழியைத் தேர்ந்தெடுக்கவும்',
      'lang_download_prompt': 'மொழித் தொகுப்பு பதிவிறக்கப்படவில்லை. இப்போது பதிவிறக்கவா?',
      'lang_download': 'பதிவிறக்கு',
      'lang_cancel': 'ரத்துசெய்',
      'lang_downloading': 'மொழித் தொகுப்பைப் பதிவிறக்குகிறது...',
      'lang_download_wait': 'இதற்கு சிறிது நேரம் ஆகலாம். காத்திருக்கவும்.',
      'lang_download_failed': 'பதிவிறக்கம் தோல்வியடைந்தது. உங்கள் இணைப்பைச் சரிபார்த்து மீண்டும் முயற்சிக்கவும்.',
      'result_offline_banner': 'இணைய இணைப்பு இல்லை · ஆஃப்லைன் மொழிபெயர்ப்பைப் பயன்படுத்துகிறது',
      'zoom_label': 'பெரிதாக்கு',
    }
  };

  for (final lang in ['zh', 'ms', 'ta']) {
    final file = File('assets/translations/$lang.json');
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      final Map<String, dynamic> json = jsonDecode(content);
      
      final Map<String, String> currentUpdates = updates[lang]!;
      for (final entry in currentUpdates.entries) {
        json[entry.key] = entry.value;
      }
      
      file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(json));
      print('Updated \$lang.json');
    }
  }
}
