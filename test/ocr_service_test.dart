import 'package:flutter_test/flutter_test.dart';
import 'package:pembukuan/services/ocr_service.dart';

void main() {
  test('normalizes Mistral document_annotation fields', () {
    final data = OcrService.normalizeOcrData({
      'document_annotation':
          '{"plate_number":"BK 1234 AB","bon_date":"2026-08-03T00:00:00Z","netto_1":"2.000","netto_2":"1900"}',
    });

    expect(data['plate_number'], 'BK1234AB');
    expect(data['bon_date'], '2026-08-03');
    expect(data['netto_1'], 2000);
    expect(data['netto_2'], 1900);
  });
}
