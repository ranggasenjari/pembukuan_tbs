import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ocr_settings_model.dart';

class OcrResult {
  final Map<String, dynamic> data;
  final String? imagePath;
  final String? imageUrl;

  const OcrResult({required this.data, this.imagePath, this.imageUrl});
}

class OcrService {
  static final Uri mistralOcrUri = Uri.parse('https://api.mistral.ai/v1/ocr');

  final SupabaseClient _client;
  final http.Client _httpClient;

  OcrService(this._client, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  Future<OcrResult> processBonImage({
    required Uint8List bytes,
    required String fileName,
    required OcrSettingsModel settings,
    String? factoryName,
    OcrFactorySettings? factorySettings,
  }) {
    if (settings.mode == OcrMode.internal) {
      return _processInternal(
        bytes: bytes,
        fileName: fileName,
        settings: settings,
        factoryName: factoryName,
        factorySettings: factorySettings,
      );
    }
    return _processWebhook(
      bytes: bytes,
      fileName: fileName,
      settings: settings,
      factoryName: factoryName,
    );
  }

  Future<OcrResult> _processWebhook({
    required Uint8List bytes,
    required String fileName,
    required OcrSettingsModel settings,
    String? factoryName,
  }) async {
    final request = http.MultipartRequest('POST', Uri.parse(settings.webhookUrl))
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: _contentTypeFor(fileName),
        ),
      );
    if (settings.webhookKey.isNotEmpty) {
      request.headers['x-api-key'] = settings.webhookKey;
    }

    final streamed = await request.send().timeout(const Duration(minutes: 5));
    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception('OCR gagal dengan status ${streamed.statusCode}');
    }

    final payload = json.decode(body);
    final data = normalizeOcrData(_unwrapPayload(payload));
    if (factoryName != null && factoryName.trim().isNotEmpty) {
      data['factory_name'] = factoryName.trim();
    }
    return OcrResult(
      data: data,
      imagePath: data['path']?.toString(),
    );
  }

  Future<OcrResult> _processInternal({
    required Uint8List bytes,
    required String fileName,
    required OcrSettingsModel settings,
    String? factoryName,
    OcrFactorySettings? factorySettings,
  }) async {
    if (settings.mistralApiKey.isEmpty) {
      throw Exception('Mistral API Key wajib diisi di Setting OCR.');
    }

    final prompt = (factorySettings?.prompt?.trim().isNotEmpty ?? false)
        ? factorySettings!.prompt!.trim()
        : settings.mistralPrompt;
    final schemaSource = (factorySettings?.outputSchema?.trim().isNotEmpty ??
            false)
        ? factorySettings!.outputSchema!
        : settings.mistralOutputSchema;
    if (prompt.isEmpty) {
      throw Exception('Prompt Mistral wajib diisi di Setting OCR.');
    }

    final schema = json.decode(schemaSource);
    final body = {
      'model': 'mistral-ocr-latest',
      'document': {
        'type': 'image_url',
        'image_url': {
          'url':
              'data:${_mimeTypeFor(fileName)};base64,${base64Encode(bytes)}',
        },
      },
      'document_annotation_prompt': prompt,
      'document_annotation_format': schema,
    };

    final response = await _httpClient
        .post(
          mistralOcrUri,
          headers: {
            'Authorization': 'Bearer ${settings.mistralApiKey}',
            'Content-Type': 'application/json',
          },
          body: json.encode(body),
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Internal OCR gagal dengan status ${response.statusCode}');
    }

    final payload = json.decode(response.body);
    final data = normalizeOcrData(Map<String, dynamic>.from(payload));
    if (factoryName != null && factoryName.trim().isNotEmpty) {
      data['factory_name'] = factoryName.trim();
    }
    final upload = await uploadBonImage(bytes: bytes, fileName: fileName);
    return OcrResult(data: data, imagePath: upload.$1, imageUrl: upload.$2);
  }

  Future<(String, String)> uploadBonImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    final path = 'bons/${DateTime.now().millisecondsSinceEpoch}_${_safeFileName(fileName)}';
    await _client.storage
        .from('receipts')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _mimeTypeFor(fileName),
            upsert: true,
          ),
        );
    final url = _client.storage.from('receipts').getPublicUrl(path);
    return (path, url);
  }

  static Map<String, dynamic> normalizeOcrData(Map<String, dynamic> payload) {
    final rawAnnotation = payload['document_annotation'] ?? payload;
    final annotation = rawAnnotation is String
        ? Map<String, dynamic>.from(json.decode(rawAnnotation))
        : Map<String, dynamic>.from(rawAnnotation as Map);

    return {
      ...annotation,
      'ticket_number': annotation['ticket_number'],
      'bon_date': _normalizeDate(annotation['bon_date']),
      'plate_number': annotation['plate_number']
          ?.toString()
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '')
          .toUpperCase(),
      'driver_name': annotation['driver_name'],
      'relation_name': annotation['relation_name'],
      'factory_name': annotation['factory_name'],
      'fruit_origin': annotation['fruit_origin'],
      'notes': annotation['notes'] ?? annotation['catatan'],
      'netto_1': _normalizeNumber(annotation['netto_1']),
      'netto_2': _normalizeNumber(annotation['netto_2']),
    };
  }

  static Map<String, dynamic> _unwrapPayload(dynamic payload) {
    if (payload is List && payload.isNotEmpty) {
      return Map<String, dynamic>.from(payload.first as Map);
    }
    if (payload is Map) return Map<String, dynamic>.from(payload);
    throw Exception('Invalid response format');
  }

  static int? _normalizeNumber(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return null;
    return int.tryParse(value.toString().replaceAll(RegExp(r'[^\d-]'), ''));
  }

  static String? _normalizeDate(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.length >= 10 ? text.substring(0, 10) : text;
  }

  static MediaType _contentTypeFor(String fileName) {
    final mime = _mimeTypeFor(fileName).split('/');
    return MediaType(mime[0], mime[1]);
  }

  static String _mimeTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  static String _safeFileName(String fileName) {
    final clean = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    return clean.isEmpty ? 'bon.jpg' : clean;
  }
}
