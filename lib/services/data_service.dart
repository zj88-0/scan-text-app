import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_text.dart';
import 'auth_service.dart';

/// DataService handles all local data persistence for the app.
///
/// SAVED TEXTS are scoped per Firebase user. The SharedPreferences key is
///   `saved_texts_<uid>` so two accounts on the same device never share data.
///
/// SCAN COUNT STRATEGY (free-tier enforcement):
///   Firestore is the authoritative store for the daily scan count so the
///   limit cannot be bypassed by reinstalling the app or clearing local data.
///   Local SharedPreferences acts as a fast cache:
///     • syncScanCountFromRemote() — pulls Firestore count into local cache.
///       Call once after sign-in (done in _goNext inside main.dart).
///     • getFreeScanCount()        — reads local cache synchronously (fast).
///     • incrementFreeScanCount()  — increments in Firestore AND local cache.
///     • resetFreeScanCount()      — clears both local and Firestore.
class DataService {
  // Legacy single-user key — kept only so we can migrate old data if needed.
  static const String _savedTextsKeyLegacy = 'saved_texts';

  static const String _languageKey     = 'app_language';
  static const String _fontSizeKey     = 'font_size';
  static const String _serverUrlKey    = 'server_url';

  static const String _voiceNamePrefix      = 'voice_name_';
  static const String _voiceLocalePrefix    = 'voice_locale_';


  // Local scan-count cache keys (mirrors Firestore values after sync).
  static const String _scanCountKey     = 'free_scan_count';
  static const String _scanCountDateKey = 'free_scan_count_date';

  static const String _defaultServerUrl = 'https://api-udefzonqpa-as.a.run.app';

  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Clear any stale dev URLs saved from development.
    final saved = _prefs!.getString(_serverUrlKey) ?? '';
    if (saved.contains('localhost') ||
        saved.contains('127.0.0.1') ||
        saved.contains('10.0.') ||
        saved.contains('192.168.')) {
      await _prefs!.remove(_serverUrlKey);
    }
  }

  SharedPreferences get _p {
    if (_prefs == null) {
      throw StateError('DataService not initialised. Call init() first.');
    }
    return _prefs!;
  }

  // ─── Per-user saved-texts key ─────────────────────────────────────────────

  /// Returns `saved_texts_<uid>` for the currently signed-in user, or falls
  /// back to the legacy key if no user is available (should not normally happen
  /// once the app requires sign-in, but keeps things safe).
  String get _savedTextsKey {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return _savedTextsKeyLegacy;
    return 'saved_texts_$uid';
  }

  // ─── Saved Texts ─────────────────────────────────────────────────────────

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

  // ─── Language ─────────────────────────────────────────────────────────────

  String getLanguage() => _p.getString(_languageKey) ?? 'en';

  Future<void> setLanguage(String langCode) async {
    await _p.setString(_languageKey, langCode);
  }

  // ─── Font Size ────────────────────────────────────────────────────────────

  double getFontSize() => _p.getDouble(_fontSizeKey) ?? 1.5;

  Future<void> setFontSize(double size) async {
    await _p.setDouble(_fontSizeKey, size);
  }

  // ─── Server URL ───────────────────────────────────────────────────────────

  String getServerUrl() => _p.getString(_serverUrlKey) ?? _defaultServerUrl;

  Future<void> setServerUrl(String url) async {
    final clean = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    await _p.setString(_serverUrlKey, clean);
  }

  // ─── Per-Language TTS Voice ───────────────────────────────────────────────

  String? getVoiceNameForLang(String langCode) =>
      _p.getString('$_voiceNamePrefix$langCode');

  String? getVoiceLocaleForLang(String langCode) =>
      _p.getString('$_voiceLocalePrefix$langCode');

  Future<void> setVoiceForLang(String langCode, String name, String locale) async {
    await _p.setString('$_voiceNamePrefix$langCode', name);
    await _p.setString('$_voiceLocalePrefix$langCode', locale);
  }

  Future<void> clearVoiceForLang(String langCode) async {
    await _p.remove('$_voiceNamePrefix$langCode');
    await _p.remove('$_voiceLocalePrefix$langCode');
  }

  Map<String, Map<String, String>> getAllSavedVoices(List<String> langCodes) {
    final result = <String, Map<String, String>>{};
    for (final code in langCodes) {
      final name   = getVoiceNameForLang(code);
      final locale = getVoiceLocaleForLang(code);
      if (name != null && locale != null) {
        result[code] = {'name': name, 'locale': locale};
      }
    }
    return result;
  }

  // ─── Legacy single-voice helpers ──────────────────────────────────────────

  String? getPreferredVoiceName() => getVoiceNameForLang('en');
  String? getPreferredVoiceLocale() => getVoiceLocaleForLang('en');
  Future<void> setPreferredVoice(String name, String locale) async =>
      setVoiceForLang('en', name, locale);
  Future<void> clearPreferredVoice() async => clearVoiceForLang('en');

  // ─── Free-tier Scan Count ─────────────────────────────────────────────────

  /// Pulls the authoritative count from Firestore into the local cache.
  /// Call once after sign-in (done in _goNext inside main.dart).
  /// HomeScreen reads the local cache synchronously via getFreeScanCount().
  Future<void> syncScanCountFromRemote() async {
    try {
      final remote = await AuthService().getRemoteScanCount();
      final today  = _todayKey();
      await _p.setInt(_scanCountKey, remote);
      await _p.setString(_scanCountDateKey, today);
      debugPrint('[DataService] syncScanCountFromRemote → $remote');
    } catch (e) {
      debugPrint('[DataService] syncScanCountFromRemote error: $e');
      // Keep whatever is in local cache.
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// How many scans have been used today (free tier) — reads local cache.
  /// Always returns 0 for a new day (local date check).
  int getFreeScanCount() {
    final savedDate = _p.getString(_scanCountDateKey) ?? '';
    if (savedDate != _todayKey()) return 0;
    return _p.getInt(_scanCountKey) ?? 0;
  }

  /// Increments the daily scan counter in Firestore (source of truth) AND
  /// in the local cache. Returns the new count.
  /// If Firestore fails, only the local count is incremented (offline fallback).
  Future<int> incrementFreeScanCount() async {
    // 1. Increment in Firestore (authoritative).
    int? remoteCount;
    try {
      remoteCount = await AuthService().incrementRemoteScanCount();
      debugPrint('[DataService] incrementFreeScanCount remote → $remoteCount');
    } catch (e) {
      debugPrint('[DataService] Remote increment failed, using local fallback: $e');
    }

    // 2. Update local cache to match Firestore, or +1 locally if offline.
    final today     = _todayKey();
    final savedDate = _p.getString(_scanCountDateKey) ?? '';
    final localCount = (savedDate == today) ? (_p.getInt(_scanCountKey) ?? 0) : 0;

    final newCount = remoteCount ?? (localCount + 1);
    await _p.setInt(_scanCountKey, newCount);
    await _p.setString(_scanCountDateKey, today);

    debugPrint('[DataService] incrementFreeScanCount local cache → $newCount');
    return newCount;
  }

  /// Resets the daily scan counter (call after upgrading to premium).
  /// Clears both local cache and Firestore.
  Future<void> resetFreeScanCount() async {
    await _p.remove(_scanCountKey);
    await _p.remove(_scanCountDateKey);
    try {
      await AuthService().resetRemoteScanCount();
      debugPrint('[DataService] resetFreeScanCount OK');
    } catch (e) {
      debugPrint('[DataService] Remote reset failed: $e');
    }
  }

}