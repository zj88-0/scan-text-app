import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/saved_text.dart';
import 'data_service.dart';

/// ApiService handles all HTTP communication with the Node.js backend.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final DataService _dataService = DataService();

  String get _baseUrl => _dataService.getServerUrl();

  /// Send an image file to the backend for OCR + translation.
  /// Returns a [SavedText] with all 4 language translations.
  Future<SavedText> processImage(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/api/ocr/process');

    final request = http.MultipartRequest('POST', uri);
    request.files.add(
      await http.MultipartFile.fromPath('image', imageFile.path),
    );

    http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw const SocketException('Request timed out'),
      );
    } on SocketException catch (e) {
      throw ApiException('Cannot connect to server: ${e.message}');
    } catch (e) {
      throw ApiException('Network error: $e');
    }

    final responseBody = await streamedResponse.stream.bytesToString();

    if (streamedResponse.statusCode != 200) {
      String errMsg = 'Server error (${streamedResponse.statusCode})';
      try {
        final errJson = jsonDecode(responseBody);
        errMsg = errJson['error'] ?? errMsg;
      } catch (_) {}
      throw ApiException(errMsg);
    }

    final json = jsonDecode(responseBody) as Map<String, dynamic>;

    if (json['success'] != true) {
      throw ApiException(json['error'] ?? 'Unknown server error');
    }

    final originalText = json['originalText'] as String? ?? '';
    final rawTranslations = json['translations'] as Map<String, dynamic>? ?? {};
    final translations = rawTranslations.map(
      (k, v) => MapEntry(k, v?.toString() ?? originalText),
    );

    final savedText = SavedText(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      originalText: originalText,
      translations: Map<String, String>.from(translations),
      createdAt: DateTime.now(),
    );

    return savedText;
  }

  /// Test connectivity to the server.
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/health'))
          .timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}
