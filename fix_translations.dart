import 'dart:convert';
import 'dart:io';

void main() {
  final Map<String, Map<String, String>> updates = {
    'zh': {
      'lang_download_success': '完成！语言已准备就绪。',
      'feedback_success': '感谢您的反馈！',
      'feedback_title_premium': '帮助我们改进！',
      'feedback_title_free': '帮助我们改进！',
      'feedback_q1': '该应用程序容易使用吗？',
      'feedback_scale_1': '非常困难',
      'feedback_scale_5': '非常容易',
      'feedback_q2': '翻译准确吗？',
      'feedback_scale_1_acc': '很差',
      'feedback_scale_5_acc': '完美',
      'feedback_q3': '任何其他反馈或建议？',
      'feedback_optional': '（可选）',
      'feedback_q3_hint': '在此处输入您的反馈...',
      'feedback_submit': '提交反馈',
    },
    'ms': {
      'lang_download_success': 'Selesai! Bahasa sedia digunakan.',
      'feedback_success': 'Terima kasih atas maklum balas anda!',
      'feedback_title_premium': 'Bantu Kami Maju!',
      'feedback_title_free': 'Bantu Kami Maju!',
      'feedback_q1': 'Adakah aplikasi ini mudah digunakan?',
      'feedback_scale_1': 'Sangat Sukar',
      'feedback_scale_5': 'Sangat Mudah',
      'feedback_q2': 'Sejauh manakah ketepatan terjemahan?',
      'feedback_scale_1_acc': 'Lemah',
      'feedback_scale_5_acc': 'Sempurna',
      'feedback_q3': 'Sebarang maklum balas atau cadangan lain?',
      'feedback_optional': '(Pilihan)',
      'feedback_q3_hint': 'Taip maklum balas anda di sini...',
      'feedback_submit': 'Hantar Maklum Balas',
      'lang_name_el': 'Yunani',
      'lang_name_bn': 'Benggali',
      'lang_name_gu': 'Gujerat',
    },
    'ta': {
      'lang_download_success': 'முடிந்தது! மொழி தயார்.',
      'feedback_success': 'உங்கள் கருத்துக்கு நன்றி!',
      'feedback_title_premium': 'மேம்படுத்த எங்களுக்கு உதவுங்கள்!',
      'feedback_title_free': 'மேம்படுத்த எங்களுக்கு உதவுங்கள்!',
      'feedback_q1': 'பயன்பாட்டை பயன்படுத்துவது எவ்வளவு எளிது?',
      'feedback_scale_1': 'மிகவும் கடினம்',
      'feedback_scale_5': 'மிகவும் எளிது',
      'feedback_q2': 'மொழிபெயர்ப்பு எவ்வளவு துல்லியமானது?',
      'feedback_scale_1_acc': 'மோசம்',
      'feedback_scale_5_acc': 'சரியானது',
      'feedback_q3': 'வேறு ஏதேனும் கருத்து அல்லது பரிந்துரைகள் உள்ளதா?',
      'feedback_optional': '(விருப்பத்திற்குரியது)',
      'feedback_q3_hint': 'உங்கள் கருத்தை இங்கே தட்டச்சு செய்க...',
      'feedback_submit': 'கருத்தை சமர்ப்பி',
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
      print('Updated $lang.json');
    }
  }
}
