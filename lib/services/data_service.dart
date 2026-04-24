import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_text.dart';

/// DataService handles all local data persistence for the app.
class DataService {
  static const String _savedTextsKey = 'saved_texts';
  static const String _languageKey = 'app_language';
  static const String _fontSizeKey = 'font_size';
  static const String _serverUrlKey = 'server_url';

  // Per-language voice keys use prefix + langCode, e.g. 'voice_name_en'
  static const String _voiceNamePrefix = 'voice_name_';
  static const String _voiceLocalePrefix = 'voice_locale_';

  // ── Scan count keys ─────────────────────────────────────────────────────
  static const String _scanCountKey = 'free_scan_count';
  static const String _scanCountDateKey = 'free_scan_count_date';

  // ── Paste your Firebase Function trigger URL below ───────────────────────
  static const String _defaultServerUrl = 'https://api-udefzonqpa-as.a.run.app';
  // ─────────────────────────────────────────────────────────────────────────

  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Clear any stale localhost / 10.0.x.x / 192.168.x.x URL saved from
    // development so the app always falls back to the Firebase default.
    final saved = _prefs!.getString(_serverUrlKey) ?? '';
    if (saved.contains('localhost') ||
        saved.contains('127.0.0.1') ||
        saved.contains('10.0.') ||
        saved.contains('192.168.')) {
      await _prefs!.remove(_serverUrlKey);
    }
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

  /// Updates an existing saved text in place (e.g. after adding a new translation).
  Future<void> updateText(SavedText text) async {
    final existing = _p.getStringList(_savedTextsKey) ?? [];
    final updated = existing.map((s) {
      try {
        final t = SavedText.fromJsonString(s);
        return t.id == text.id ? text.toJsonString() : s;
      } catch (_) {
        return s;
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

  // ─── Per-Language TTS Voice ──────────────────────────────────────────────────

  /// Get the saved voice name for a specific language code. Returns null if none set.
  String? getVoiceNameForLang(String langCode) =>
      _p.getString('$_voiceNamePrefix$langCode');

  /// Get the saved voice locale for a specific language code. Returns null if none set.
  String? getVoiceLocaleForLang(String langCode) =>
      _p.getString('$_voiceLocalePrefix$langCode');

  /// Save the preferred voice for a specific language code.
  Future<void> setVoiceForLang(String langCode, String name, String locale) async {
    await _p.setString('$_voiceNamePrefix$langCode', name);
    await _p.setString('$_voiceLocalePrefix$langCode', locale);
  }

  /// Clear the preferred voice for a specific language code.
  Future<void> clearVoiceForLang(String langCode) async {
    await _p.remove('$_voiceNamePrefix$langCode');
    await _p.remove('$_voiceLocalePrefix$langCode');
  }

  /// Returns a map of langCode → {'name': ..., 'locale': ...} for all languages
  /// that have a saved voice. Only includes entries where both name and locale exist.
  Map<String, Map<String, String>> getAllSavedVoices(List<String> langCodes) {
    final result = <String, Map<String, String>>{};
    for (final code in langCodes) {
      final name = getVoiceNameForLang(code);
      final locale = getVoiceLocaleForLang(code);
      if (name != null && locale != null) {
        result[code] = {'name': name, 'locale': locale};
      }
    }
    return result;
  }

  // ─── Legacy single-voice helpers (kept for backward compatibility) ────────────
  // These delegate to the English voice slot so old call-sites don't break
  // until they are updated to use the per-language variants above.

  /// @deprecated Use getVoiceNameForLang(langCode) instead.
  String? getPreferredVoiceName() => getVoiceNameForLang('en');

  /// @deprecated Use getVoiceLocaleForLang(langCode) instead.
  String? getPreferredVoiceLocale() => getVoiceLocaleForLang('en');

  /// @deprecated Use setVoiceForLang(langCode, name, locale) instead.
  Future<void> setPreferredVoice(String name, String locale) async {
    await setVoiceForLang('en', name, locale);
  }

  /// @deprecated Use clearVoiceForLang(langCode) instead.
  Future<void> clearPreferredVoice() async {
    await clearVoiceForLang('en');
  }

  // ─── Free-tier Scan Count ────────────────────────────────────────────────────

  /// Returns today's date as a yyyy-MM-dd string.
  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// How many scans have been used today (free tier).
  int getFreeScanCount() {
    final savedDate = _p.getString(_scanCountDateKey) ?? '';
    if (savedDate != _todayKey()) return 0; // new day — reset in-memory
    return _p.getInt(_scanCountKey) ?? 0;
  }

  /// Increment the daily free-tier scan counter and return the new value.
  Future<int> incrementFreeScanCount() async {
    final today = _todayKey();
    final savedDate = _p.getString(_scanCountDateKey) ?? '';
    int count = (savedDate == today) ? (_p.getInt(_scanCountKey) ?? 0) : 0;
    count++;
    await _p.setInt(_scanCountKey, count);
    await _p.setString(_scanCountDateKey, today);
    return count;
  }

  /// Reset the daily free-tier scan counter (useful after upgrading to premium).
  Future<void> resetFreeScanCount() async {
    await _p.remove(_scanCountKey);
    await _p.remove(_scanCountDateKey);
  }
}