import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'translation_service.dart';

/// TtsService wraps flutter_tts for easy read-aloud of extracted text.
/// Adds [speakAndWait] which resolves only after the utterance completes,
/// enabling line-by-line highlighting in ResultScreen.
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  Completer<void>? _completer;

  // Legacy callbacks (kept for backwards compat)
  Function()? onComplete;
  Function()? onStart;

  bool get isSpeaking => _isSpeaking;

  Future<void> init() async {
    await _tts.setVolume(1.0);
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
      onStart?.call();
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
      onComplete?.call();
      _completer?.complete();
      _completer = null;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      onComplete?.call();
      _completer?.completeError(msg);
      _completer = null;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      onComplete?.call();
      _completer?.complete();
      _completer = null;
    });
  }

  /// Speak [text] and return immediately (fire-and-forget).
  Future<void> speak(String text, {String? langCode}) async {
    if (text.isEmpty) return;
    final locale = langCode != null
        ? (AppTranslations.ttsLocales[langCode] ?? 'en-US')
        : AppTranslations().ttsLocale;
    await _tts.setLanguage(locale);
    await _tts.speak(text);
  }

  /// Speak [text] and wait until it is fully spoken before returning.
  /// Used by ResultScreen to advance the highlight line by line.
  Future<void> speakAndWait(String text, {String? langCode}) async {
    if (text.isEmpty) return;
    _completer = Completer<void>();
    await speak(text, langCode: langCode);
    await _completer!.future;
  }

  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
    _completer?.complete();
    _completer = null;
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  Future<List<dynamic>> getAvailableLanguages() async {
    return await _tts.getLanguages;
  }
}
