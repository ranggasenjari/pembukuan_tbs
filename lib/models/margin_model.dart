class MarginModel {
  final String id;
  final DateTime createdAt;
  final DateTime transactionDate;
  final int offtakerAmount;
  final int realAmount;
  final int marginAmount;

  MarginModel({
    required this.id,
    required this.createdAt,
    required this.transactionDate,
    required this.offtakerAmount,
    required this.realAmount,
    required this.marginAmount,
  });

  factory MarginModel.fromJson(Map<String, dynamic> json) {
    return MarginModel(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      transactionDate: DateTime.parse(json['transaction_date']),
      offtakerAmount: (json['offtaker_amount'] as num?)?.toInt() ?? 0,
      realAmount: (json['real_amount'] as num?)?.toInt() ?? 0,
      marginAmount: (json['margin_amount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_date': transactionDate.toIso8601String(),
      'offtaker_amount': offtakerAmount,
      'real_amount': realAmount,
      'margin_amount': marginAmount,
    };
  }
}
