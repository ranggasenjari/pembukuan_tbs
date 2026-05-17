class DepositModel {
  final String id;
  final String source;
  final int amount;
  final String? category;
  final DateTime createdAt;

  DepositModel({
    required this.id,
    required this.source,
    required this.amount,
    this.category,
    required this.createdAt,
  });

  factory DepositModel.fromJson(Map<String, dynamic> json) {
    return DepositModel(
      id: json['id'],
      source: json['source'],
      amount: json['amount'],
      category: json['category'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'source': source,
      'amount': amount,
      'category': category,
      'created_at': createdAt.toIso8601String(),
    };
  }

  DepositModel copyWith({
    String? id,
    String? source,
    int? amount,
    String? category,
    DateTime? createdAt,
  }) {
    return DepositModel(
      id: id ?? this.id,
      source: source ?? this.source,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
