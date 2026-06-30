import 'dart:convert';

/// Represents a single saved QR scan result (URL + AI summary + translations).
class QrSavedText {
  final String id;

  /// The UID of the Firebase user who created this entry.
  final String userId;

  /// The URL decoded from the QR code.
  final String url;

  /// The AI-generated summary of the page at [url] (always English).
  final String summary;

  /// Cached translations keyed by language code (en, zh, ms, ta, etc.).
  /// The original English summary is always stored under 'en'.
  final Map<String, String> translations;

  final DateTime createdAt;

  QrSavedText({
    required this.id,
    required this.userId,
    required this.url,
    required this.summary,
    Map<String, String>? translations,
    required this.createdAt,
  }) : translations = translations ?? {'en': summary};

  /// Returns the summary for [langCode], falling back to the English summary.
  String forLanguage(String langCode) =>
      translations[langCode]?.isNotEmpty == true
          ? translations[langCode]!
          : summary;

  /// Short preview suitable for list cards (first 80 chars of summary).
  String get previewText {
    final text = summary.replaceAll('\n', ' ').trim();
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  /// Short display of the domain from the URL.
  String get urlDomain {
    try {
      final uri = Uri.parse(url);
      return uri.host.isNotEmpty ? uri.host : url;
    } catch (_) {
      return url;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'url': url,
        'summary': summary,
        'translations': translations,
        'createdAt': createdAt.toIso8601String(),
      };

  factory QrSavedText.fromJson(Map<String, dynamic> json) => QrSavedText(
        id: json['id'] as String,
        userId: json['userId'] as String? ?? '',
        url: json['url'] as String,
        summary: json['summary'] as String,
        translations: json['translations'] != null
            ? Map<String, String>.from(json['translations'] as Map)
            : {'en': json['summary'] as String},
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());
  factory QrSavedText.fromJsonString(String s) =>
      QrSavedText.fromJson(jsonDecode(s));
}

