import 'dart:convert';
import 'package:flutter/services.dart';
import 'data_service.dart';

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
      if (langCode != 'en') await load('en');
    }
  }

  Future<void> loadSaved() async {
    final saved = _dataService.getLanguage();
    await load(saved);
  }

  String t(String key) => _strings[key] ?? key;

  String get ttsLocale => ttsLocales[_currentLang] ?? 'en-US';
}
