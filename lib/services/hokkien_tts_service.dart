import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'groq_translation_service.dart';

/// HokkienTtsService — offline Hokkien (閩南語 / Southern Min) TTS using
/// a Sherpa-ONNX VITS model bundled with the app.
///
/// MODEL FILES (already in assets/models/):
///   • model.onnx   — Hokkien VITS model (~114 MB)
///   • tokens.txt   — phoneme token dictionary
///   • lexicon.txt  — pronunciation dictionary
///   • date.fst     — text normalisation for dates
///   • number.fst   — text normalisation for numbers
///
/// On first use, all files are copied to app-documents storage so that
/// the native Sherpa library can open them from the filesystem.
class HokkienTtsService {
  static final HokkienTtsService _instance = HokkienTtsService._internal();
  factory HokkienTtsService() => _instance;
  HokkienTtsService._internal();

  sherpa.OfflineTts? _tts;
  final AudioPlayer _player = AudioPlayer();

  bool _initAttempted = false;
  bool _isReady = false;
  bool _isSpeaking = false;

  /// True once the model has loaded successfully.
  bool get isReady => _isReady;
  bool get isSpeaking => _isSpeaking;

  // ── Initialisation ────────────────────────────────────────────────────────

  /// Initialises the engine. Safe to call multiple times — only runs once.
  Future<void> init() async {
    if (_initAttempted) return;
    _initAttempted = true;

    try {
      final modelPath = await _copyAsset('assets/models/model.onnx');
      final tokensPath = await _copyAsset('assets/models/tokens.txt');
      final lexiconPath = await _copyAsset('assets/models/lexicon.txt');
      final dateFstPath = await _copyAsset('assets/models/date.fst');
      final numberFstPath = await _copyAsset('assets/models/number.fst');

      sherpa.initBindings();

      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: modelPath,
            tokens: tokensPath,
            lexicon: lexiconPath,
            dataDir: '',
            noiseScale: 0.667,
            noiseScaleW: 0.8,
            lengthScale: 1.0,
          ),
          numThreads: 2,
          debug: false,
          provider: 'cpu',
        ),
        ruleFsts: '$numberFstPath,$dateFstPath',
        ruleFars: '',
      );

      _tts = sherpa.OfflineTts(config);
      _isReady = true;
      debugPrint('[HokkienTTS] Engine ready');
    } catch (e) {
      debugPrint('[HokkienTTS] Init failed: $e');
      _isReady = false;
    }
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    // Auto-initialise on first call so callers don't need to call init() manually.
    if (!_isReady) {
      await init();
    }
    if (!_isReady || _tts == null) return;
    try {
      await _player.stop();
      _isSpeaking = true;

      String textToSpeak = text;
      


      final audio = _tts!.generate(text: textToSpeak, sid: 0, speed: 0.9);
      if (audio.samples.isEmpty) {
        _isSpeaking = false;
        return;
      }

      final dir = await getTemporaryDirectory();
      final wavPath = '${dir.path}/hokkien_out.wav';
      await _writeWav(wavPath, audio.samples, audio.sampleRate);

      await _player.play(DeviceFileSource(wavPath));
      await _player.onPlayerComplete.first; // wait until clip finishes
      _isSpeaking = false;
    } catch (e) {
      _isSpeaking = false;
      debugPrint('[HokkienTTS] speak error: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
    _isSpeaking = false;
  }

  Future<void> setMuted(bool muted) async {
    await _player.setVolume(muted ? 0.0 : 1.0);
  }

  void dispose() {
    _tts?.free();
    _tts = null;
    _player.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Copies [assetPath] to the app-documents directory the first time,
  /// then returns the absolute path for subsequent calls.
  Future<String> _copyAsset(String assetPath) async {
    final docs = await getApplicationDocumentsDirectory();
    final fileName = assetPath.split('/').last;
    final dest = File('${docs.path}/hokkien_tts/$fileName');

    if (!dest.existsSync()) {
      await dest.parent.create(recursive: true);
      final data = await rootBundle.load(assetPath);
      await dest.writeAsBytes(data.buffer.asUint8List(), flush: true);
      debugPrint('[HokkienTTS] Copied $fileName → ${dest.path}');
    }
    return dest.path;
  }
  // ── WAV helpers ───────────────────────────────────────────────────────────

  /// Writes [samples] (Float32, range −1..1) as a 16-bit PCM WAV file.
  Future<void> _writeWav(
      String path, List<double> samples, int sampleRate) async {
    final pcm = Int16List(samples.length);
    for (int i = 0; i < samples.length; i++) {
      pcm[i] = (samples[i] * 32767.0).clamp(-32768, 32767).toInt();
    }

    final dataBytes = pcm.buffer.asUint8List();
    final header = ByteData(44);

    // RIFF chunk descriptor
    _setStr(header, 0, 'RIFF');
    header.setUint32(4, 36 + dataBytes.length, Endian.little);
    _setStr(header, 8, 'WAVE');

    // fmt sub-chunk
    _setStr(header, 12, 'fmt ');
    header.setUint32(16, 16, Endian.little); // sub-chunk size
    header.setUint16(20, 1, Endian.little); // PCM = 1
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, sampleRate, Endian.little); // sample rate
    header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little); // block align
    header.setUint16(34, 16, Endian.little); // bits per sample

    // data sub-chunk
    _setStr(header, 36, 'data');
    header.setUint32(40, dataBytes.length, Endian.little);

    final file = File(path);
    final sink = file.openWrite();
    sink.add(header.buffer.asUint8List());
    sink.add(dataBytes);
    await sink.flush();
    await sink.close();
  }

  void _setStr(ByteData bd, int offset, String s) {
    for (int i = 0; i < s.length; i++) {
      bd.setUint8(offset + i, s.codeUnitAt(i));
    }
  }
}
