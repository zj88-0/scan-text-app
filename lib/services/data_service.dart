import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_text.dart';

/// DataService handles all local data persistence for the app.
class DataService {
  static const String _savedTextsKey = 'saved_texts';
  static const String _languageKey = 'app_language';
  static const String _fontSizeKey = 'font_size';
  static const String _serverUrlKey = 'server_url';
  static const String _preferredVoiceNameKey = 'preferred_voice_name';
  static const String _preferredVoiceLocaleKey = 'preferred_voice_locale';
  static const String _defaultServerUrl = 'http://10.187.129.145:3000';

  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _p {
    if (_prefs == null) throw StateError('DataService not initialised. Call init() first.');
    return _prefs!;
  }

  // ─── Saved Texts ────────────────────────────────────────────────────────────

  Future<List<SavedText>> getSavedTexts() async {
    final raw = _p.getStringList(_savedTextsKey) ?? [];
    final texts = raw.map((s) {
      try {
        return SavedText.fromJsonString(s);
      } catch (_) {
        return null;
      }
    }).whereType<SavedText>().toList();
    texts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return texts;
  }

  Future<void> saveText(SavedText text) async {
    final existing = _p.getStringList(_savedTextsKey) ?? [];
    existing.insert(0, text.toJsonString());
    await _p.setStringList(_savedTextsKey, existing);
  }

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

  Future<bool> textExists(String id) async {
    final texts = await getSavedTexts();
    return texts.any((t) => t.id == id);
  }

  Future<void> clearAllTexts() async {
    await _p.remove(_savedTextsKey);
  }

  // ─── Language ────────────────────────────────────────────────────────────────

  String getLanguage() => _p.getString(_languageKey) ?? 'en';

  Future<void> setLanguage(String langCode) async {
    await _p.setString(_languageKey, langCode);
  }

  // ─── Font Size ───────────────────────────────────────────────────────────────

  double getFontSize() => _p.getDouble(_fontSizeKey) ?? 1.5;

  Future<void> setFontSize(double size) async {
    await _p.setDouble(_fontSizeKey, size);
  }

  // ─── Server URL ──────────────────────────────────────────────────────────────

  String getServerUrl() => _p.getString(_serverUrlKey) ?? _defaultServerUrl;

  Future<void> setServerUrl(String url) async {
    final clean = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    await _p.setString(_serverUrlKey, clean);
  }

  // ─── Preferred TTS Voice ─────────────────────────────────────────────────────

  String? getPreferredVoiceName() => _p.getString(_preferredVoiceNameKey);

  String? getPreferredVoiceLocale() => _p.getString(_preferredVoiceLocaleKey);

  Future<void> setPreferredVoice(String name, String locale) async {
    await _p.setString(_preferredVoiceNameKey, name);
    await _p.setString(_preferredVoiceLocaleKey, locale);
  }

  Future<void> clearPreferredVoice() async {
    await _p.remove(_preferredVoiceNameKey);
    await _p.remove(_preferredVoiceLocaleKey);
  }
}
