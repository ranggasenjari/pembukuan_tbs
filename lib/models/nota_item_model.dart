class NotaItemModel {
  final String id;
  final String notaId;
  final String bonId;
  final DateTime createdAt;

  NotaItemModel({
    required this.id,
    required this.notaId,
    required this.bonId,
    required this.createdAt,
  });

  factory NotaItemModel.fromJson(Map<String, dynamic> json) {
    return NotaItemModel(
      id: json['id'],
      notaId: json['invoice_id'],
      bonId: json['bon_id'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {'invoice_id': notaId, 'bon_id': bonId};
  }
}
