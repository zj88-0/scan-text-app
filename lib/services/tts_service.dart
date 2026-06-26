import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'translation_service.dart';
import 'data_service.dart';
import 'hokkien_tts_service.dart';

/// TtsService wraps flutter_tts for easy read-aloud of extracted text.
/// Each language can have its own preferred voice, set via VoiceSelectionScreen.
/// Falls back to locale-based voice selection when no preferred voice is saved.
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
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete();
      }
      _completer = null;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      onComplete?.call();
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.completeError(msg);
      }
      _completer = null;
    });

    _tts.setCancelHandler(() {
      _isSpeaking = false;
      onComplete?.call();
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete();
      }
      _completer = null;
    });
  }

  /// Apply the user's saved preferred voice for a given [langCode].
  /// If no voice is saved for that language, falls back to the locale for [langCode].
  Future<void> applyPreferredVoice({String? langCode}) async {
    final data = DataService();
    final code = langCode ?? AppTranslations().currentLang;
    final voiceName = data.getVoiceNameForLang(code);
    final voiceLocale = data.getVoiceLocaleForLang(code);

    if (voiceName != null && voiceLocale != null) {
      try {
        await _tts.setVoice({'name': voiceName, 'locale': voiceLocale});
        return;
      } catch (_) {}
    }

    // Fallback: use the locale for this language
    final locale = AppTranslations.ttsLocales[code] ?? 'en-US';
    await _tts.setLanguage(locale);
  }

  /// Speak [text] using the saved preferred voice for [langCode].
  /// For Chinese, routes to the correct dialect engine.
  Future<void> speak(String text, {String? langCode}) async {
    if (text.isEmpty) return;

    final data = DataService();
    final code = langCode ?? AppTranslations().currentLang;

    // ── Chinese dialect routing ───────────────────────────────────────────
    if (code == 'zh') {
      final dialect = data.getChineseDialect();
      if (dialect == 'hokkien') {
        _isSpeaking = true;
        onStart?.call();
        await HokkienTtsService().speak(text);
        _isSpeaking = false;
        onComplete?.call();
        if (_completer != null && !_completer!.isCompleted) {
          _completer!.complete();
        }
        return;
      }
      // Mandarin or Cantonese: use system TTS with saved voice or locale.
      final preferredName   = data.getVoiceNameForDialect(dialect) ?? data.getVoiceNameForLang('zh');
      final preferredLocale = data.getVoiceLocaleForDialect(dialect) ?? data.getVoiceLocaleForLang('zh');
      if (preferredName != null && preferredLocale != null) {
        await _tts.setVoice({'name': preferredName, 'locale': preferredLocale});
      } else {
        final fallback = dialect == 'cantonese' ? 'zh-HK' : 'zh-CN';
        await _tts.setLanguage(fallback);
      }
      await _tts.speak(text);
      return;
    }

    // ── All other languages ───────────────────────────────────────────────
    final preferredName   = data.getVoiceNameForLang(code);
    final preferredLocale = data.getVoiceLocaleForLang(code);
    if (preferredName != null && preferredLocale != null) {
      await _tts.setVoice({'name': preferredName, 'locale': preferredLocale});
    } else {
      final locale = AppTranslations.ttsLocales[code] ?? 'en-US';
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
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete();
      }
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
    await HokkienTtsService().stop(); // stop Hokkien engine if it was speaking
    _isSpeaking = false;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete();
    }
    _completer = null;
  }

  Future<bool> interruptCurrent() async {
    // Only interrupt FlutterTts, because Hokkien is already instant via setVolume.
    if (_isSpeaking && !HokkienTtsService().isSpeaking) {
      await _tts.stop();
      // Wait for the native TTS engine to fully reset before allowing the next speak call.
      // _tts.stop() also triggers the cancel handler, but this delay prevents rapid back-to-back speak calls.
      await Future.delayed(const Duration(milliseconds: 300));
      _isSpeaking = false;
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete();
      }
      _completer = null;
      return true;
    }
    return false;
  }

  Future<void> setMuted(bool muted) async {
    // Use 0.01 instead of 0.0. A volume of 0.0 causes Android's native TTS to
    // optimise away the speech entirely, causing it to instantly skip to the end.
    // 0.01 forces it to play silently but keeps the exact normal timing.
    await _tts.setVolume(muted ? 0.01 : 1.0);
    await HokkienTtsService().setMuted(muted);
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