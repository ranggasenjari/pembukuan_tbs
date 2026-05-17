enum PaymentStatus {
  belumDibayar,
  tertagih,
  lunas;

  String get value {
    switch (this) {
      case PaymentStatus.belumDibayar:
        return 'BELUM_DIBAYAR';
      case PaymentStatus.tertagih:
        return 'TERTAGIH';
      case PaymentStatus.lunas:
        return 'LUNAS';
    }
  }

  String get label {
    switch (this) {
      case PaymentStatus.belumDibayar:
        return 'Belum Dibayar';
      case PaymentStatus.tertagih:
        return 'Tertagih';
      case PaymentStatus.lunas:
        return 'Lunas';
    }
  }
}

extension PaymentStatusX on PaymentStatus {
  static PaymentStatus fromString(String status) {
    switch (status) {
      case 'BELUM_DIBAYAR':
        return PaymentStatus.belumDibayar;
      case 'TERTAGIH':
        return PaymentStatus.tertagih;
      case 'LUNAS':
        return PaymentStatus.lunas;
      default:
        return PaymentStatus.belumDibayar;
    }
  }
}
