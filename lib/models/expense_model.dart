class ExpenseModel {
  final String id;
  final DateTime createdAt;
  final DateTime expenseDate;
  final String recipientName;
  final String category;
  final double amount;

  ExpenseModel({
    required this.id,
    required this.createdAt,
    required this.expenseDate,
    required this.recipientName,
    required this.category,
    required this.amount,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'],
      createdAt: DateTime.parse(json['created_at']),
      expenseDate: DateTime.parse(json['expense_date']),
      recipientName: json['recipient_name'],
      category: json['category'],
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'expense_date': expenseDate.toIso8601String(),
      'recipient_name': recipientName,
      'category': category,
      'amount': amount.toInt(),
    };
  }
}
