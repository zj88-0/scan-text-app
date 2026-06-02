import 'dart:io';
import 'dart:convert';

void main() {
  final Map<String, Map<String, String>> translations = {
    'zh': {
      "wifi_check_not_wifi": "未连接 Wi-Fi",
      "wifi_check_desc": "您正在使用移动数据。下载大文件（约 30 MB）可能会很慢并消耗您的数据流量。",
      "wifi_check_wait": "等待 Wi-Fi",
      "wifi_check_download": "仍要下载",
      "wifi_check_no_internet": "无网络连接",
      "wifi_check_no_internet_desc": "您的手机未连接到互联网。请打开 Wi-Fi 并重试。",
      "wifi_check_ok": "确定"
    },
    'ms': {
      "wifi_check_not_wifi": "Bukan pada Wi-Fi",
      "wifi_check_desc": "Anda sedang menggunakan data selular. Memuat turun fail besar (~30 MB) mungkin lambat dan menggunakan pelan data anda.",
      "wifi_check_wait": "Tunggu Wi-Fi",
      "wifi_check_download": "Muat Turun Juga",
      "wifi_check_no_internet": "Tiada Internet",
      "wifi_check_no_internet_desc": "Telefon anda tidak disambungkan ke internet. Sila hidupkan Wi-Fi dan cuba lagi.",
      "wifi_check_ok": "OK"
    },
    'ta': {
      "wifi_check_not_wifi": "வைஃபை இல்லை",
      "wifi_check_desc": "நீங்கள் மொபைல் டேட்டாவைப் பயன்படுத்துகிறீர்கள். பெரிய கோப்புகளை (~30 MB) பதிவிறக்குவது மெதுவாக இருக்கலாம் மற்றும் உங்கள் டேட்டாவைக் குறைக்கலாம்.",
      "wifi_check_wait": "வைஃபைக்காக காத்திருங்கள்",
      "wifi_check_download": "எப்படியும் பதிவிறக்கு",
      "wifi_check_no_internet": "இணையம் இல்லை",
      "wifi_check_no_internet_desc": "உங்கள் தொலைபேசி இணையத்துடன் இணைக்கப்படவில்லை. வைஃபை இயக்கி மீண்டும் முயற்சிக்கவும்.",
      "wifi_check_ok": "சரி"
    }
  };

  for (final entry in translations.entries) {
    final lang = entry.key;
    final file = File('assets/translations/$lang.json');
    if (!file.existsSync()) continue;
    
    final map = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    for (final t in entry.value.entries) {
      map[t.key] = t.value;
    }
    file.writeAsStringSync(JsonEncoder.withIndent('  ').convert(map));
  }
}
