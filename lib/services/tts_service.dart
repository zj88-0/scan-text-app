import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'translation_service.dart';
import 'data_service.dart';

/// TtsService wraps flutter_tts for easy read-aloud of extracted text.
/// Supports line-by-line highlighting via [speakAndWait], and per-voice
/// selection via [speakWithVoice] and [applyPreferredVoice].
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isSpeaking = false;
  Completer<void>? _completer;

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

    await applyPreferredVoice();
  }

  /// Apply the user's saved preferred voice.
  Future<void> applyPreferredVoice() async {
    final data = DataService();
    final voiceName = data.getPreferredVoiceName();
    final voiceLocale = data.getPreferredVoiceLocale();
    if (voiceName != null && voiceLocale != null) {
      try {
        await _tts.setVoice({'name': voiceName, 'locale': voiceLocale});
      } catch (_) {}
    }
  }

  /// Speak [text] (fire-and-forget). Uses preferred voice if set, else
  /// falls back to locale derived from [langCode].
  Future<void> speak(String text, {String? langCode}) async {
    if (text.isEmpty) return;

    final data = DataService();
    final preferredName = data.getPreferredVoiceName();
    final preferredLocale = data.getPreferredVoiceLocale();

    if (preferredName != null && preferredLocale != null) {
      await _tts.setVoice({'name': preferredName, 'locale': preferredLocale});
    } else {
      final locale = langCode != null
          ? (AppTranslations.ttsLocales[langCode] ?? 'en-US')
          : AppTranslations().ttsLocale;
      await _tts.setLanguage(locale);
    }
    await _tts.speak(text);
  }

  /// Preview a specific voice in VoiceSelectionScreen.
  Future<void> speakWithVoice(
      String text, String voiceName, String voiceLocale) async {
    if (text.isEmpty) return;
    _completer = Completer<void>();
    try {
      await _tts.setVoice({'name': voiceName, 'locale': voiceLocale});
      await _tts.speak(text);
      await _completer!.future;
    } catch (_) {
      _completer?.complete();
      _completer = null;
    }
  }

  /// Speak [text] and wait until it finishes. Used for line-by-line highlight.
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

  /// All voices on the device — list of {'name': ..., 'locale': ...} maps.
  Future<List<dynamic>> getAvailableVoices() async {
    try {
      return await _tts.getVoices;
    } catch (_) {
      return [];
    }
  }
}
