import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pembukuan/models/ocr_settings_model.dart';

void main() {
  test('loads default webhook settings', () {
    final settings = OcrSettingsModel.fromJson(null);

    expect(settings.mode, OcrMode.webhook);
    expect(settings.webhookUrl, isNotEmpty);
    expect(json.decode(settings.mistralOutputSchema), isA<Map>());
  });

  test('keeps configured internal OCR values from json', () {
    final settings = OcrSettingsModel.fromJson({
      'mode': 'internal',
      'webhook_url': 'https://ocr.example/webhook',
      'webhook_key': 'webhook-key',
      'mistral_api_key': 'mistral-key',
      'mistral_prompt': 'Extract',
      'mistral_output_schema': '{"type":"json_schema"}',
    });

    expect(settings.mode, OcrMode.internal);
    expect(settings.webhookUrl, 'https://ocr.example/webhook');
    expect(settings.webhookKey, 'webhook-key');
    expect(settings.mistralApiKey, 'mistral-key');
  });
}
