import 'package:flutter_test/flutter_test.dart';
import 'package:pembukuan/core/enums.dart';

void main() {
  test('PaymentStatus parser keeps legacy database values compatible', () {
    expect(
      PaymentStatusX.fromString('BELUM_DIBAYAR'),
      PaymentStatus.belumDibayar,
    );
    expect(PaymentStatusX.fromString('TERTAGIH'), PaymentStatus.tertagih);
    expect(PaymentStatusX.fromString('LUNAS'), PaymentStatus.lunas);
  });
}
