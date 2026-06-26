import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'data_service.dart';
import 'mlkit_translation_service.dart';

/// AppTranslations loads the correct JSON translation file and provides
/// string lookups. Changing the language reloads the correct file.
class AppTranslations {
  static final AppTranslations _instance = AppTranslations._internal();
  factory AppTranslations() => _instance;
  AppTranslations._internal();

  final DataService _dataService = DataService();

  Map<String, String> _strings = {};
  String _currentLang = 'en';

  static const Map<String, String> languageNames = {
    'en': 'English',
    'zh': '中文',
    'ms': 'Melayu',
    'ta': 'தமிழ்',
  };

  static const Map<String, String> ttsLocales = {
    'en': 'en-US',
    'zh': 'zh-CN',
    'ms': 'ms-MY',
    'ta': 'ta-IN',
  };

  String get currentLang => _currentLang;

  Future<void> load(String langCode) async {
    try {
      final raw = await rootBundle.loadString('assets/translations/$langCode.json');
      _strings = Map<String, String>.from(jsonDecode(raw));
      _currentLang = langCode;
      await _dataService.setLanguage(langCode);
    } catch (_) {
      try {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/translations/$langCode.json');

        if (await file.exists()) {
          final raw = await file.readAsString();
          final cachedStrings = Map<String, String>.from(jsonDecode(raw));

          // Merge with English so any newly added keys fallback to English instead of showing raw keys
          final rawEn = await rootBundle.loadString('assets/translations/en.json');
          final enStrings = Map<String, String>.from(jsonDecode(rawEn));

          _strings = Map<String, String>.from(enStrings)..addAll(cachedStrings);
          _currentLang = langCode;
          await _dataService.setLanguage(langCode);
        } else {
          // It's a dynamically downloaded language not yet cached
          final rawEn = await rootBundle.loadString('assets/translations/en.json');
          final enStrings = Map<String, String>.from(jsonDecode(rawEn));

          final translatedMap = await OnDeviceTranslationService().translateUIStrings(enStrings, langCode);
          _strings = translatedMap;
          _currentLang = langCode;
          await _dataService.setLanguage(langCode);

          await file.parent.create(recursive: true);
          await file.writeAsString(jsonEncode(translatedMap));
        }
      } catch (e) {
        if (langCode != 'en') await load('en');
      }
    }
  }

  /// Lightweight language switch — only reads from the bundled asset file or an
  /// already-cached translated file. Does NOT trigger translateUIStrings(), so
  /// it is safe to call while model downloads are in progress (e.g. setup screen).
  /// Falls back to English if the file is not yet available.
  Future<void> loadFast(String langCode) async {
    // 1. Try the bundled asset (en, zh, ms, ta always ship with the app).
    try {
      final raw = await rootBundle.loadString('assets/translations/$langCode.json');
      _strings = Map<String, String>.from(jsonDecode(raw));
      _currentLang = langCode;
      await _dataService.setLanguage(langCode);
      return;
    } catch (_) {}

    // 2. Try an already-cached translated file (written by a previous load() call).
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/translations/$langCode.json');
      if (await file.exists()) {
        final raw = await file.readAsString();
        final cachedStrings = Map<String, String>.from(jsonDecode(raw));

        // Merge with English so any newly added keys fallback to English
        final rawEn = await rootBundle.loadString('assets/translations/en.json');
        final enStrings = Map<String, String>.from(jsonDecode(rawEn));

        _strings = Map<String, String>.from(enStrings)..addAll(cachedStrings);
        _currentLang = langCode;
        await _dataService.setLanguage(langCode);
        return;
      }
    } catch (_) {}

    // 3. File not available yet — fall back to English without touching ML Kit.
    if (langCode != 'en') await loadFast('en');
  }

  Future<void> preTranslate(String langCode) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/translations/$langCode.json');
    if (await file.exists()) return;

    final rawEn = await rootBundle.loadString('assets/translations/en.json');
    final enStrings = Map<String, String>.from(jsonDecode(rawEn));

    final translatedMap = await OnDeviceTranslationService().translateUIStrings(enStrings, langCode);

    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(translatedMap));
  }

  /// Deletes the cached translated JSON for [langCode] from the documents
  /// directory. Call this when the user removes a language model so that a
  /// future re-download triggers a fresh translation with the latest logic.
  Future<void> clearCache(String langCode) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/translations/$langCode.json');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  Future<void> loadSaved() async {
    final saved = _dataService.getLanguage();
    await load(saved);
  }

  String t(String key) => _strings[key] ?? key;

  String get ttsLocale => ttsLocales[_currentLang] ?? 'en-US';
}
