import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// LocalOcrService performs fully offline (on-device) text recognition using
/// Google ML Kit. No network request is made.
///
/// Call [recognize] with a [File] and receive the raw extracted text string.
/// Call [dispose] when the service is no longer needed.
class LocalOcrService {
  static final LocalOcrService _instance = LocalOcrService._internal();
  factory LocalOcrService() => _instance;
  LocalOcrService._internal();

  // Latin script covers English, Malay, and most European languages.
  // If you need additional scripts (e.g. Chinese, Tamil) you can add more
  // recognisers or switch to TextRecognitionScript.chinese etc.
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Runs ML Kit OCR on [imageFile] and returns the extracted text.
  /// Returns an empty string if no text was found.
  Future<String> recognize(File imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.absolute.path);
      final RecognizedText result =
          await _recognizer.processImage(inputImage);
      debugPrint(
          '[LocalOcrService] recognized ${result.text.length} chars');
      return result.text;
    } catch (e) {
      debugPrint('[LocalOcrService] error: $e');
      return '';
    }
  }

  /// Release the underlying ML Kit recogniser.
  /// Safe to call multiple times.
  Future<void> dispose() async {
    await _recognizer.close();
  }
}
