import 'dart:convert';

/// Represents a single saved OCR result with translations in configured languages.
class SavedText {
  final String id;
  final String originalText;
  final Map<String, String> translations;
  final DateTime createdAt;

  /// Optional user-defined label shown on the card. Null means no name set.
  String? name;

  SavedText({
    required this.id,
    required this.originalText,
    required this.translations,
    required this.createdAt,
    this.name,
  });

  String get english => translations['en'] ?? originalText;
  String get chinese => translations['zh'] ?? originalText;
  String get malay => translations['ms'] ?? originalText;
  String get tamil => translations['ta'] ?? originalText;

  String forLanguage(String langCode) {
    return translations[langCode] ?? originalText;
  }

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
    if (name != null) 'name': name,
  };

  factory SavedText.fromJson(Map<String, dynamic> json) => SavedText(
    id: json['id'] as String,
    originalText: json['originalText'] as String,
    translations: Map<String, String>.from(json['translations'] as Map),
    createdAt: DateTime.parse(json['createdAt'] as String),
    name: json['name'] as String?,
  );

  String toJsonString() => jsonEncode(toJson());
  factory SavedText.fromJsonString(String s) => SavedText.fromJson(jsonDecode(s));
}
