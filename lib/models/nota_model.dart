import '../core/enums.dart';

class NotaModel {
  final String id;
  final String notaNumber;
  final DateTime notaDate;
  final double totalAmount;
  final PaymentStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? relationAgentId;
  final String? relationAgentName;
  final String? recipientName;
  final String? recipientAddress;
  final List<String> accounts;

  final int itemCount;

  NotaModel({
    required this.id,
    required this.notaNumber,
    required this.notaDate,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.relationAgentId,
    this.relationAgentName,
    this.itemCount = 0,
    this.recipientName,
    this.recipientAddress,
    this.accounts = const [],
  });

  factory NotaModel.fromJson(Map<String, dynamic> json) {
    int count = 0;
    if (json['nota_items'] != null) {
      if (json['nota_items'] is List) {
        final list = json['nota_items'] as List;
        if (list.isNotEmpty &&
            list[0] is Map &&
            (list[0] as Map).containsKey('count')) {
          count = list[0]['count'] as int;
        } else {
          count = list.length;
        }
      } else if (json['nota_items'] is Map &&
          json['nota_items']['count'] != null) {
        count = json['nota_items']['count'] as int;
      }
    }

    final accountsRaw = json['relation_agents']?['relation_agent_accounts'];
    final accounts = <String>[];
    if (accountsRaw is List) {
      for (final acc in accountsRaw) {
        final name = acc['account_name'] ?? '';
        final number = acc['account_number'] ?? '';
        if (name.isNotEmpty || number.isNotEmpty) {
          accounts.add('$name $number'.trim());
        }
      }
    }

    return NotaModel(
      id: json['id'],
      notaNumber: json['invoice_number'],
      notaDate: DateTime.parse(json['invoice_date']),
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: PaymentStatusX.fromString(json['status']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      relationAgentId: json['relation_agent_id'],
      relationAgentName: json['relation_agents']?['name'],
      itemCount: count,
      recipientName: json['recipient_name'],
      recipientAddress: json['recipient_address'],
      accounts: accounts,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'invoice_number': notaNumber,
      'invoice_date': notaDate.toIso8601String(),
      'total_amount': totalAmount.toInt(),
      'status': status.value,
      'relation_agent_id': relationAgentId,
      'recipient_name': recipientName,
      'recipient_address': recipientAddress,
    };
  }
}
