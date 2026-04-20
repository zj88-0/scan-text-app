import 'dart:convert';

/// Represents a single saved OCR result with translations in 4 languages.
class SavedText {
  final String id;
  final String originalText;
  final Map<String, String> translations; // keys: en, zh, ms, ta
  final DateTime createdAt;

  SavedText({
    required this.id,
    required this.originalText,
    required this.translations,
    required this.createdAt,
  });

  /// Convenience getters for each language
  String get english => translations['en'] ?? originalText;
  String get chinese => translations['zh'] ?? originalText;
  String get malay => translations['ms'] ?? originalText;
  String get tamil => translations['ta'] ?? originalText;

  /// Get translation by language code
  String forLanguage(String langCode) {
    return translations[langCode] ?? originalText;
  }

  /// First ~80 chars of English text, used as a preview title
  String get previewTitle {
    final text = english.replaceAll('\n', ' ').trim();
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'originalText': originalText,
    'translations': translations,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedText.fromJson(Map<String, dynamic> json) => SavedText(
    id: json['id'] as String,
    originalText: json['originalText'] as String,
    translations: Map<String, String>.from(json['translations'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  String toJsonString() => jsonEncode(toJson());
  factory SavedText.fromJsonString(String s) => SavedText.fromJson(jsonDecode(s));
}
