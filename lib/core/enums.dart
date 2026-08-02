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

  String get bonLabel {
    switch (this) {
      case PaymentStatus.belumDibayar:
        return 'Belum Dibuat Nota';
      case PaymentStatus.tertagih:
        return 'Menunggu Pembayaran';
      case PaymentStatus.lunas:
        return 'Lunas';
    }
  }

  String get notaLabel {
    switch (this) {
      case PaymentStatus.belumDibayar:
        return 'Belum Terbit / Data Lama';
      case PaymentStatus.tertagih:
        return 'Menunggu Pembayaran';
      case PaymentStatus.lunas:
        return 'Lunas';
    }
  }

  String get bonDescription {
    switch (this) {
      case PaymentStatus.belumDibayar:
        return 'Bon belum masuk nota dan masih bisa diedit atau dihapus.';
      case PaymentStatus.tertagih:
        return 'Bon sudah masuk nota dan menunggu pembayaran atau bukti transfer.';
      case PaymentStatus.lunas:
        return 'Bon sudah selesai dibayar.';
    }
  }

  String get notaDescription {
    switch (this) {
      case PaymentStatus.belumDibayar:
        return 'Status lama: nota belum ditandai terbit.';
      case PaymentStatus.tertagih:
        return 'Nota sudah terbit dan menunggu pembayaran atau bukti transfer.';
      case PaymentStatus.lunas:
        return 'Nota sudah memiliki pembayaran.';
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
