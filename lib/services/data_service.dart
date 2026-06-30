import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/saved_text.dart';
import '../models/qr_saved_text.dart';
import 'auth_service.dart';

/// DataService handles all local data persistence for the app.
///
/// SAVED TEXTS are scoped per Firebase user. The SharedPreferences key is
///   `saved_texts_<uid>` so two accounts on the same device never share data.
///
/// SCAN COUNT STRATEGY:
///
///   LOGGED-IN USERS (non-anonymous):
///     Firestore is the authoritative store (cannot be bypassed by reinstall).
///     Local SharedPreferences acts as a fast cache:
///       • syncScanCountFromRemote() — pulls Firestore count into local cache.
///         Called once after sign-in (done in _goNext inside main.dart).
///       • getFreeScanCount()        — reads local cache synchronously.
///       • incrementFreeScanCount()  — increments Firestore AND local cache.
///       • resetFreeScanCount()      — clears both local and Firestore.
///
///   GUEST USERS (anonymous):
///     Stored under a STABLE DEVICE-LEVEL key ('guest_scan_count' /
///     'guest_scan_date') that is completely separate from any logged-in
///     user's keys and from Firestore.  The anonymous UID is intentionally
///     NOT used as part of the key because a new anonymous UID is issued on
///     every sign-in, which would silently reset the counter each session.
///     The guest key survives app restarts and is only reset at midnight
///     (same daily-reset behaviour as free logged-in users).
class DataService {
  // Legacy single-user key — kept only so we can migrate old data if needed.
  static const String _savedTextsKeyLegacy = 'saved_texts';

  static const String _languageKey  = 'app_language';
  static const String _fontSizeKey  = 'font_size';
  static const String _serverUrlKey = 'server_url';

  static const String _voiceNamePrefix   = 'voice_name_';
  static const String _voiceLocalePrefix = 'voice_locale_';
  static const String _chineseDialectKey = 'chinese_dialect';

  static const String _autoReadKey = 'auto_read';
  static const String _startMutedKey = 'start_muted';

  // ── Scan mode preference ──────────────────────────────────────────────────
  // 'ai'    → use the remote AI/server OCR (default)
  // 'local' → use on-device ML Kit OCR (offline)
  static const String _scanModeKey = 'scan_mode';

  // ── Logged-in user scan-count cache keys (mirrors Firestore after sync) ──
  static const String _scanCountKey     = 'free_scan_count';
  static const String _scanCountDateKey = 'free_scan_count_date';

  // ── Guest scan-count keys — stable device-level, never UID-scoped ────────
  static const String _guestScanCountKey     = 'guest_scan_count';
  static const String _guestScanCountDateKey = 'guest_scan_date';

  static const String _defaultServerUrl =
      'https://api-udefzonqpa-as.a.run.app';

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

  // ── Guest helper ──────────────────────────────────────────────────────────

  /// Returns true when the current Firebase user is anonymous (guest).
  bool get _isGuest {
    final user = AuthService().currentUser;
    return user == null || user.isAnonymous;
  }

  // ── Per-user saved-texts key ──────────────────────────────────────────────

  /// Returns `saved_texts_<uid>` for the currently signed-in user, or falls
  /// back to the legacy key if no user is available.
  String get _savedTextsKey {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return _savedTextsKeyLegacy;
    if (_isGuest) return 'saved_texts_guest_local';
    return 'saved_texts_$uid';
  }

  // ── Saved Texts ───────────────────────────────────────────────────────────

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

  // ── QR Scan Results ───────────────────────────────────────────────────────

  /// Returns the SharedPreferences key for QR scans scoped to the current user.
  String get _qrScansKey {
    final uid = AuthService().currentUser?.uid;
    if (uid == null || uid.isEmpty) return 'qr_scans_guest_local';
    if (_isGuest) return 'qr_scans_guest_local';
    return 'qr_scans_$uid';
  }

  Future<List<QrSavedText>> getQrScans() async {
    final raw = _p.getStringList(_qrScansKey) ?? [];
    final scans = raw.map((s) {
      try {
        return QrSavedText.fromJsonString(s);
      } catch (_) {
        return null;
      }
    }).whereType<QrSavedText>().toList();
    scans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return scans;
  }

  Future<void> saveQrScan(QrSavedText scan) async {
    final existing = _p.getStringList(_qrScansKey) ?? [];
    existing.insert(0, scan.toJsonString());
    await _p.setStringList(_qrScansKey, existing);
  }

  Future<void> deleteQrScan(String id) async {
    final existing = _p.getStringList(_qrScansKey) ?? [];
    final updated = existing.where((s) {
      try {
        final t = QrSavedText.fromJsonString(s);
        return t.id != id;
      } catch (_) {
        return true;
      }
    }).toList();
    await _p.setStringList(_qrScansKey, updated);
  }

  Future<void> updateQrScan(QrSavedText scan) async {
    final existing = _p.getStringList(_qrScansKey) ?? [];
    final updated = existing.map((s) {
      try {
        final t = QrSavedText.fromJsonString(s);
        return t.id == scan.id ? scan.toJsonString() : s;
      } catch (_) {
        return s;
      }
    }).toList();
    await _p.setStringList(_qrScansKey, updated);
  }


  // ── Language ──────────────────────────────────────────────────────────────

  String getLanguage() => _p.getString(_languageKey) ?? 'en';

  Future<void> setLanguage(String langCode) async {
    await _p.setString(_languageKey, langCode);
  }

  // ── Auto Read ─────────────────────────────────────────────────────────────

  bool getAutoRead() => _p.getBool(_autoReadKey) ?? true;

  Future<void> setAutoRead(bool autoRead) async {
    await _p.setBool(_autoReadKey, autoRead);
  }

  bool getStartMuted() => _p.getBool(_startMutedKey) ?? false;

  Future<void> setStartMuted(bool startMuted) async {
    await _p.setBool(_startMutedKey, startMuted);
  }

  // ── Scan Mode ─────────────────────────────────────────────────────────────

  /// Returns 'ai' (default) or 'local'.
  String getScanMode() => _p.getString(_scanModeKey) ?? 'ai';

  Future<void> setScanMode(String mode) async {
    assert(mode == 'ai' || mode == 'local');
    await _p.setString(_scanModeKey, mode);
  }

  // ── Font Size ─────────────────────────────────────────────────────────────

  double getFontSize() => _p.getDouble(_fontSizeKey) ?? 1.5;

  Future<void> setFontSize(double size) async {
    await _p.setDouble(_fontSizeKey, size);
  }

  // ── Server URL ────────────────────────────────────────────────────────────

  String getServerUrl() => _p.getString(_serverUrlKey) ?? _defaultServerUrl;

  Future<void> setServerUrl(String url) async {
    final clean = url.trimRight().replaceAll(RegExp(r'/+$'), '');
    await _p.setString(_serverUrlKey, clean);
  }

  // ── Per-Language TTS Voice ────────────────────────────────────────────────

  String? getVoiceNameForLang(String langCode) =>
      _p.getString('$_voiceNamePrefix$langCode');

  String? getVoiceLocaleForLang(String langCode) =>
      _p.getString('$_voiceLocalePrefix$langCode');

  Future<void> setVoiceForLang(
      String langCode, String name, String locale) async {
    await _p.setString('$_voiceNamePrefix$langCode', name);
    await _p.setString('$_voiceLocalePrefix$langCode', locale);
  }

  Future<void> clearVoiceForLang(String langCode) async {
    await _p.remove('$_voiceNamePrefix$langCode');
    await _p.remove('$_voiceLocalePrefix$langCode');
  }

  // ── Chinese Dialect Voice Preference ──────────────────────────────────────

  String? getVoiceNameForDialect(String dialect) =>
      _p.getString('$_voiceNamePrefix${dialect}_zh');

  String? getVoiceLocaleForDialect(String dialect) =>
      _p.getString('$_voiceLocalePrefix${dialect}_zh');

  Future<void> setVoiceForDialect(
      String dialect, String name, String locale) async {
    await _p.setString('$_voiceNamePrefix${dialect}_zh', name);
    await _p.setString('$_voiceLocalePrefix${dialect}_zh', locale);
  }

  // ── Chinese Dialect Preference ────────────────────────────────────────────

  /// Returns the saved Chinese dialect: 'mandarin', 'cantonese', or 'hokkien'.
  /// Defaults to 'mandarin' if nothing has been saved yet.
  String getChineseDialect() =>
      _p.getString(_chineseDialectKey) ?? 'mandarin';

  Future<void> setChineseDialect(String dialect) async {
    await _p.setString(_chineseDialectKey, dialect);
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

  // ── Legacy single-voice helpers ───────────────────────────────────────────

  String? getPreferredVoiceName()  => getVoiceNameForLang('en');
  String? getPreferredVoiceLocale() => getVoiceLocaleForLang('en');
  Future<void> setPreferredVoice(String name, String locale) async =>
      setVoiceForLang('en', name, locale);
  Future<void> clearPreferredVoice() async => clearVoiceForLang('en');

  // ── Scan Count (public API — routes to guest or logged-in path) ───────────

  /// Pulls the authoritative count from Firestore into the local cache.
  /// Only meaningful for logged-in (non-anonymous) users.
  /// For guests this is a no-op — their count lives in [_guestScanCountKey].
  Future<void> syncScanCountFromRemote() async {
    if (_isGuest) return; // Guest count never touches Firestore.
    try {
      final remote = await AuthService().getRemoteScanCount();
      final today  = _todayKey();
      await _p.setInt(_scanCountKey, remote);
      await _p.setString(_scanCountDateKey, today);
      debugPrint('[DataService] syncScanCountFromRemote → $remote');
    } catch (e) {
      debugPrint('[DataService] syncScanCountFromRemote error: $e');
    }
  }

  /// How many scans have been used today.
  /// Routes to the guest path or the logged-in path automatically.
  int getFreeScanCount() {
    return _isGuest ? _getGuestScanCount() : _getLoggedInScanCount();
  }

  /// Increments the daily scan counter.
  /// Routes to the guest path or the logged-in path automatically.
  Future<int> incrementFreeScanCount() async {
    return _isGuest
        ? await _incrementGuestScanCount()
        : await _incrementLoggedInScanCount();
  }

  /// Resets the daily scan counter (call after upgrading to premium).
  Future<void> resetFreeScanCount() async {
    if (_isGuest) {
      await _resetGuestScanCount();
    } else {
      await _resetLoggedInScanCount();
    }
  }

  /// Decrements the daily scan counter by 1 (minimum 0).
  /// Used when the user earns a reward via a rewarded video ad.
  /// Only updates the local SharedPreferences cache; the next remote sync
  /// will reconcile any drift for logged-in users.
  Future<void> decrementFreeScanCount() async {
    if (_isGuest) {
      final today     = _todayKey();
      final savedDate = _p.getString(_guestScanCountDateKey) ?? '';
      final current   = (savedDate == today) ? (_p.getInt(_guestScanCountKey) ?? 0) : 0;
      final next      = (current - 1).clamp(0, current);
      await _p.setInt(_guestScanCountKey, next);
      await _p.setString(_guestScanCountDateKey, today);
      debugPrint('[DataService] guest decrementFreeScanCount → $next');
    } else {
      final today     = _todayKey();
      final savedDate = _p.getString(_scanCountDateKey) ?? '';
      final current   = (savedDate == today) ? (_p.getInt(_scanCountKey) ?? 0) : 0;
      final next      = (current - 1).clamp(0, current);
      await _p.setInt(_scanCountKey, next);
      await _p.setString(_scanCountDateKey, today);
      debugPrint('[DataService] decrementFreeScanCount → $next');
    }
  }

  // ── Guest scan-count implementation ───────────────────────────────────────
  //
  // Uses a fixed device-level key so the count persists across all
  // anonymous sessions on the same device and is never shared with any
  // logged-in user's count.

  int _getGuestScanCount() {
    final savedDate = _p.getString(_guestScanCountDateKey) ?? '';
    if (savedDate != _todayKey()) return 0;
    return _p.getInt(_guestScanCountKey) ?? 0;
  }

  Future<int> _incrementGuestScanCount() async {
    final today      = _todayKey();
    final savedDate  = _p.getString(_guestScanCountDateKey) ?? '';
    final current    = (savedDate == today) ? (_p.getInt(_guestScanCountKey) ?? 0) : 0;
    final next       = current + 1;
    await _p.setInt(_guestScanCountKey, next);
    await _p.setString(_guestScanCountDateKey, today);
    debugPrint('[DataService] guest incrementFreeScanCount → $next');
    return next;
  }

  Future<void> _resetGuestScanCount() async {
    await _p.remove(_guestScanCountKey);
    await _p.remove(_guestScanCountDateKey);
    debugPrint('[DataService] guest resetFreeScanCount OK');
  }

  // ── Logged-in scan-count implementation ───────────────────────────────────

  int _getLoggedInScanCount() {
    final savedDate = _p.getString(_scanCountDateKey) ?? '';
    if (savedDate != _todayKey()) return 0;
    return _p.getInt(_scanCountKey) ?? 0;
  }

  Future<int> _incrementLoggedInScanCount() async {
    // 1. Increment in Firestore (authoritative).
    int? remoteCount;
    try {
      remoteCount = await AuthService().incrementRemoteScanCount();
      debugPrint('[DataService] incrementFreeScanCount remote → $remoteCount');
    } catch (e) {
      debugPrint('[DataService] Remote increment failed, using local fallback: $e');
    }

    // 2. Update local cache to match Firestore, or +1 locally if offline.
    final today      = _todayKey();
    final savedDate  = _p.getString(_scanCountDateKey) ?? '';
    final localCount = (savedDate == today) ? (_p.getInt(_scanCountKey) ?? 0) : 0;

    final newCount = remoteCount ?? (localCount + 1);
    await _p.setInt(_scanCountKey, newCount);
    await _p.setString(_scanCountDateKey, today);

    debugPrint('[DataService] incrementFreeScanCount local cache → $newCount');
    return newCount;
  }

  Future<void> _resetLoggedInScanCount() async {
    await _p.remove(_scanCountKey);
    await _p.remove(_scanCountDateKey);
    try {
      await AuthService().resetRemoteScanCount();
      debugPrint('[DataService] resetFreeScanCount OK');
    } catch (e) {
      debugPrint('[DataService] Remote reset failed: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }
}