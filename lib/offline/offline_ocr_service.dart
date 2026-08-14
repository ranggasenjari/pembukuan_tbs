import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../services/ocr_service.dart';

/// Direct Mistral OCR for the offline flavor. Unlike the legacy OCR service it
/// never touches Supabase Storage; the caller owns the local image lifecycle.
class OfflineOcrService {
  OfflineOcrService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Map<String, dynamic>> process({
    required Uint8List bytes,
    required String fileName,
    required String mistralApiKey,
    required String prompt,
    required String outputSchema,
  }) async {
    if (mistralApiKey.isEmpty) throw StateError('Mistral API Key belum disimpan di perangkat.');
    final mime = fileName.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
    final response = await _client.post(
      OcrService.mistralOcrUri,
      headers: {'Authorization': 'Bearer $mistralApiKey', 'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': 'mistral-ocr-latest',
        'document': {'type': 'image_url', 'image_url': {'url': 'data:$mime;base64,${base64Encode(bytes)}'}},
        'document_annotation_prompt': prompt,
        'document_annotation_format': jsonDecode(outputSchema),
      }),
    ).timeout(const Duration(minutes: 5));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('OCR Mistral gagal (${response.statusCode}).');
    }
    return OcrService.normalizeOcrData(Map<String, dynamic>.from(jsonDecode(response.body) as Map));
  }

  void dispose() => _client.close();
}
