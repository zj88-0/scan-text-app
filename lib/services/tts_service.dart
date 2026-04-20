import 'package:flutter_tts/flutter_tts.dart';
import 'translation_service.dart';

/// TtsService wraps flutter_tts for easy read-aloud of extracted text.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  Function()? onComplete;
  Function()? onStart;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.45); // Slower rate for elderly users
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
      onStart?.call();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      onComplete?.call();
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      onComplete?.call();
    });
  }

  /// Speak the provided text using the current app language.
  Future<void> speak(String text, {String? langCode}) async {
    if (text.isEmpty) return;
    final locale = langCode != null
        ? (AppTranslations.ttsLocales[langCode] ?? 'en-US')
        : AppTranslations().ttsLocale;
    await _tts.setLanguage(locale);
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  Future<List<dynamic>> getAvailableLanguages() async {
    return await _tts.getLanguages;
  }
}
