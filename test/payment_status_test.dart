import 'package:flutter_test/flutter_test.dart';
import 'package:pembukuan/core/enums.dart';

void main() {
  group('PaymentStatus contextual labels', () {
    test('uses bon workflow labels', () {
      expect(PaymentStatus.belumDibayar.bonLabel, 'Belum Dibuat Nota');
      expect(PaymentStatus.tertagih.bonLabel, 'Menunggu Pembayaran');
      expect(PaymentStatus.lunas.bonLabel, 'Lunas');
    });

    test('uses nota payment labels', () {
      expect(PaymentStatus.belumDibayar.notaLabel, 'Belum Terbit / Data Lama');
      expect(PaymentStatus.tertagih.notaLabel, 'Menunggu Pembayaran');
      expect(PaymentStatus.lunas.notaLabel, 'Lunas');
    });

    test('keeps persisted status values unchanged', () {
      expect(PaymentStatus.belumDibayar.value, 'BELUM_DIBAYAR');
      expect(PaymentStatus.tertagih.value, 'TERTAGIH');
      expect(PaymentStatus.lunas.value, 'LUNAS');
    });
  });
}
