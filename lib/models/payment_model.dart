class PaymentModel {
  final String id;
  final String notaId;
  final DateTime paymentDate;
  final int amountPaid;
  final String? proofUrl;
  final DateTime createdAt;
  final String? marginId;

  PaymentModel({
    required this.id,
    required this.notaId,
    required this.paymentDate,
    required this.amountPaid,
    this.proofUrl,
    required this.createdAt,
    this.marginId,
  });

  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    return PaymentModel(
      id: json['id'],
      notaId: json['invoice_id'],
      paymentDate: DateTime.parse(json['payment_date']),
      amountPaid: (json['amount_paid'] as num?)?.toInt() ?? 0,
      proofUrl: json['proof_url'],
      createdAt: DateTime.parse(json['created_at']),
      marginId: json['margin_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_id': notaId,
      'payment_date': paymentDate.toIso8601String(),
      'amount_paid': amountPaid.toInt(),
      'proof_url': proofUrl,
      'margin_id': marginId,
    };
  }
}
