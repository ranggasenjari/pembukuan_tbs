class SubNotaModel {
  final String id;
  final String bonId;
  final String name;
  final int pricePerKg;
  final int netto2;
  final int amount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubNotaModel({
    required this.id,
    required this.bonId,
    required this.name,
    required this.pricePerKg,
    required this.netto2,
    required this.amount,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubNotaModel.fromJson(Map<String, dynamic> json) {
    return SubNotaModel(
      id: json['id'],
      bonId: json['bon_id'],
      name: json['name'] ?? '',
      pricePerKg: (json['price_per_kg'] as num?)?.toInt() ?? 0,
      netto2: (json['netto_2'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'bon_id': bonId,
      'name': name,
      'price_per_kg': pricePerKg,
      'netto_2': netto2,
      'amount': amount,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}