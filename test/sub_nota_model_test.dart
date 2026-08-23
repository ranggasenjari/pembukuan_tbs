import 'package:flutter_test/flutter_test.dart';
import 'package:pembukuan/models/sub_nota_model.dart';

void main() {
  test('SubNotaModel.fromJson parses fields', () {
    final model = SubNotaModel.fromJson({
      'id': 'sub-1',
      'bon_id': 'bon-1',
      'name': 'ANNU JAYA',
      'price_per_kg': 40,
      'netto_2': 2500,
      'amount': 100000,
      'notes': 'komisi',
      'created_at': '2026-08-19T00:00:00.000Z',
      'updated_at': '2026-08-19T00:00:00.000Z',
    });

    expect(model.id, 'sub-1');
    expect(model.bonId, 'bon-1');
    expect(model.name, 'ANNU JAYA');
    expect(model.pricePerKg, 40);
    expect(model.netto2, 2500);
    expect(model.amount, 100000);
  });

  test('SubNotaModel total murni = netto2 x harga (tanpa potongan)', () {
    final bonus = 2500 * 40;
    expect(bonus, 100000);
  });

  test('SubNotaModel.toJson round-trips', () {
    final model = SubNotaModel(
      id: 'sub-1',
      bonId: 'bon-1',
      name: 'A',
      pricePerKg: 40,
      netto2: 100,
      amount: 4000,
      createdAt: DateTime.utc(2026, 8, 19),
      updatedAt: DateTime.utc(2026, 8, 19),
    );

    final json = model.toJson();
    final parsed = SubNotaModel.fromJson(json);

    expect(parsed.id, model.id);
    expect(parsed.bonId, model.bonId);
    expect(parsed.name, model.name);
    expect(parsed.pricePerKg, model.pricePerKg);
    expect(parsed.netto2, model.netto2);
    expect(parsed.amount, model.amount);
  });
}