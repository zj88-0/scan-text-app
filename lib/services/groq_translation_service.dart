import 'dart:convert';
import 'package:http/http.dart' as http;
import 'data_service.dart';

/// GroqTranslationService calls the Node.js backend's new
/// /api/translate/smart endpoint to perform natural, context-aware
/// translation via Groq Llama 4.
///
/// Key behaviours:
///  • Only called when the user is on PREMIUM tier.
///  • Translates one language at a time (on-demand when tab is opened).
///  • Results are cached in [SavedText.translations] and persisted to
///    SharedPreferences via [DataService.updateText] — so a language is
///    never re-translated for the same text.
class GroqTranslationService {
  static final GroqTranslationService _instance =
      GroqTranslationService._internal();
  factory GroqTranslationService() => _instance;
  GroqTranslationService._internal();

  final DataService _dataService = DataService();

  String get _baseUrl => _dataService.getServerUrl();

  /// Translate [text] (English source) to [targetLangCode] using Groq AI.
  ///
  /// Returns the translated string, or the original [text] on any error.
  Future<String> translateSmart(String text, String targetLangCode) async {
    if (text.isEmpty || text == '[No text found]') return text;
    if (targetLangCode == 'en') return text;

    final uri = Uri.parse('$_baseUrl/api/translate/smart');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'targetLang': targetLangCode,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        return text; // Graceful fallback
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (json['success'] != true) return text;

      return (json['translatedText'] as String?) ?? text;
    } catch (_) {
      return text; // Network / parse error — return original
    }
  }
}
