import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_text.dart';

/// DataService handles all local data persistence for the app.
/// This is the single source of truth for saved texts and user settings.
class DataService {
  static const String _savedTextsKey = 'saved_texts';
  static const String _languageKey = 'app_language';
  static const String _fontSizeKey = 'font_size';
  static const String _serverUrlKey = 'server_url';
  static const String _defaultServerUrl = 'http://10.194.42.145:3000'; // Android emulator loopback

  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  SharedPreferences? _prefs;

  /// Call once at startup to initialise SharedPreferences
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    if (_prefs == null) throw StateError('DataService not initialised. Call init() first.');
    return _prefs!;
  }

  // ─── Saved Texts ────────────────────────────────────────────────────────────

  /// Load all saved texts, newest first.
  Future<List<SavedText>> getSavedTexts() async {
    final raw = _p.getStringList(_savedTextsKey) ?? [];
    final texts = raw.map((s) {
      try {
        return SavedText.fromJsonString(s);
      } catch (_) {
        return null;
      }
    }).whereType<SavedText>().toList();

    // Sort newest first
    texts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return texts;
  }

  /// Save a new SavedText. Prepends to existing list.
  Future<void> saveText(SavedText text) async {
    final existing = _p.getStringList(_savedTextsKey) ?? [];
    existing.insert(0, text.toJsonString());
    await _p.setStringList(_savedTextsKey, existing);
  }

  /// Delete a saved text by ID.
  Future<void> deleteText(String id) async {
    final existing = _p.getStringList(_savedTextsKey) ?? [];
    final updated = existing.where((s) {
      try {
        final t = SavedText.fromJsonString(s);
        return t.id != id;
      } catch (_) {
        return true;
      }
    }).toList();
    await _p.setStringList(_savedTextsKey, updated);
  }

  /// Check if a text with the given ID already exists.
  Future<bool> textExists(String id) async {
    final texts = await getSavedTexts();
    return texts.any((t) => t.id == id);
  }

  /// Clear all saved texts.
  Future<void> clearAllTexts() async {
    await _p.remove(_savedTextsKey);
  }

  // ─── Language ────────────────────────────────────────────────────────────────

  /// Get current app language code (en, zh, ms, ta). Default: 'en'
  String getLanguage() {
    return _p.getString(_languageKey) ?? 'en';
  }

  /// Persist the selected language code.
  Future<void> setLanguage(String langCode) async {
    await _p.setString(_languageKey, langCode);
  }

  // ─── Font Size ───────────────────────────────────────────────────────────────

  /// Get saved font size multiplier (1.0 = normal, 2.0 = double). Default: 1.5
  double getFontSize() {
    return _p.getDouble(_fontSizeKey) ?? 1.5;
  }

  /// Persist the font size multiplier.
  Future<void> setFontSize(double size) async {
    await _p.setDouble(_fontSizeKey, size);
  }

  // ─── Server URL ──────────────────────────────────────────────────────────────

  /// Get saved server base URL.
  String getServerUrl() {
    return _p.getString(_serverUrlKey) ?? _defaultServerUrl;
  }

  /// Persist the server base URL.
  Future<void> setServerUrl(String url) async {
    // Remove trailing slash
    final clean = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    await _p.setString(_serverUrlKey, clean);
  }
}
