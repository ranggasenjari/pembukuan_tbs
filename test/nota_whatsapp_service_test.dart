import 'package:flutter_test/flutter_test.dart';
import 'package:pembukuan/core/enums.dart';
import 'package:pembukuan/models/bon_model.dart';
import 'package:pembukuan/models/nota_model.dart';
import 'package:pembukuan/services/nota_whatsapp_service.dart';

void main() {
  test('builds whatsapp nota message matching Express format', () {
    final now = DateTime(2026, 7, 18);
    final nota = NotaModel(
      id: 'nota-1',
      notaNumber: 'NOTA-1',
      notaDate: now,
      totalAmount: 1000000,
      status: PaymentStatus.tertagih,
      createdAt: now,
      updatedAt: now,
      relationAgentId: 'rel-1',
      recipientName: 'AGEN MAJU',
    );
    final bon = BonModel(
      id: 'bon-1',
      bonDate: now,
      plateNumber: 'BK 1234 AA',
      driverName: 'BUDI',
      netto1: 9000,
      netto2: 1000,
      price: 1200,
      biayaBongkar: 12,
      spsiAmount: 10000,
      bpColt: 5000,
      pph: 0,
      uangMinum: 0,
      dp: 200000,
      deductions: [BonDeduction(label: 'Pengiriman', amount: 10000)],
      total: 800000,
      status: PaymentStatus.tertagih,
      createdAt: now,
      updatedAt: now,
    );

    final message = NotaWhatsappService.buildMessage(nota, [bon]);

    expect(message, contains('Relasi: AGEN MAJU'));
    expect(message, contains('*1. BK 1234 AA* — BUDI'));
    expect(message, contains('   1000 kg x Rp'));
    expect(message, contains('   *Rp 1.200.000*'));
    expect(message, contains('   *Potongan:*'));
    expect(message, contains('      SPSI:'));
    expect(message, contains('        9000 kg x Rp'));
    expect(message, contains('      BP/Colt:'));
    expect(message, contains('        Rp 5.000'));
    expect(message, contains('      Pengiriman:'));
    expect(message, contains('        Rp 10.000'));
    // Total bon = bon.total + dp (sebelum DP)
    expect(message, contains('   *Total bon: Rp 1.000.000*'));
    // TOTAL NOTA = penjumlahan total bon sebelum DP
    expect(message, contains('*TOTAL NOTA: Rp 1.000.000*'));
    // DP dan Total Akhir
    expect(message, contains('DP / Panjar: Rp 200.000'));
    expect(message, contains('*Total Akhir: Rp 800.000*'));
    // DP tidak dicantumkan pada daftar potongan
    expect(message, isNot(contains('      DP:')));
  });

  test('omits DP section when no bon has DP', () {
    final now = DateTime(2026, 7, 18);
    final nota = NotaModel(
      id: 'nota-2',
      notaNumber: 'NOTA-2',
      notaDate: now,
      totalAmount: 1000000,
      status: PaymentStatus.tertagih,
      createdAt: now,
      updatedAt: now,
      recipientName: 'AGEN MAJU',
    );
    final bon = BonModel(
      id: 'bon-2',
      bonDate: now,
      plateNumber: 'BK 1234 AA',
      driverName: 'BUDI',
      netto1: 9000,
      netto2: 1000,
      price: 1200,
      biayaBongkar: 12,
      spsiAmount: 10000,
      bpColt: 5000,
      pph: 0,
      uangMinum: 0,
      total: 1000000,
      status: PaymentStatus.tertagih,
      createdAt: now,
      updatedAt: now,
    );

    final message = NotaWhatsappService.buildMessage(nota, [bon]);

    expect(message, contains('*TOTAL NOTA: Rp 1.000.000*'));
    expect(message, isNot(contains('DP / Panjar')));
    expect(message, isNot(contains('Total Akhir')));
  });
}
