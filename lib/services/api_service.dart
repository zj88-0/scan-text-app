import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'data_service.dart';

/// ApiService handles all HTTP communication with the Node.js backend.
/// The backend now only does OCR — translation is handled on-device.
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final DataService _dataService = DataService();

  String get _baseUrl => _dataService.getServerUrl();

  /// Send an image file to the backend for OCR only.
  /// Returns the raw extracted text string.
  Future<String> processImage(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/api/ocr/process-base64');

    try {
      // 1. Convert image to base64 string
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 2. Send as JSON POST instead of Multipart
      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json', // Required for Express
        },
        body: jsonEncode({
          'image': base64Image,
          'mimeType': 'image/jpeg',
        }),
      ).timeout(const Duration(seconds: 60));

      // 3. Handle the response
      if (response.statusCode != 200) {
        throw ApiException('Server error (${response.statusCode})');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (json['success'] != true) {
        throw ApiException(json['error'] ?? 'Unknown server error');
      }

      // Only return the original extracted text — translation is done locally
      return (json['originalText'] as String?) ?? '';
    } on SocketException catch (e) {
      throw ApiException('Cannot connect to server: ${e.message}');
    } catch (e) {
      throw ApiException('Network error: $e');
    }
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