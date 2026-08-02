import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense_model.dart';
import '../models/margin_model.dart';

class ExpenseRepository {
  final SupabaseClient _client;

  ExpenseRepository(this._client);

  Future<List<ExpenseModel>> getExpenses({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _client.from('expenses').select();

    if (startDate != null) {
      query = query.gte(
        'expense_date',
        startDate.toIso8601String().split('T')[0],
      );
    }
    if (endDate != null) {
      final nextDay = DateTime.utc(endDate.year, endDate.month, endDate.day + 1);
      query = query.lt('expense_date', nextDay.toIso8601String().split('T')[0]);
    }

    final response = await query.order('expense_date', ascending: false);
    return (response as List).map((e) => ExpenseModel.fromJson(e)).toList();
  }

  Future<void> createExpense({
    required ExpenseModel expense,
    required List<String> marginIds,
  }) async {
    // 1. Insert Expense
    final expenseData = expense.toJson();
    final response = await _client
        .from('expenses')
        .insert(expenseData)
        .select()
        .single();

    final String expenseId = response['id'];

    // 2. Link to Margins
    if (marginIds.isNotEmpty) {
      final List<Map<String, dynamic>> links = marginIds
          .map((mId) => {'expense_id': expenseId, 'margin_id': mId})
          .toList();

      await _client.from('expense_margins').insert(links);
    }
  }

  Future<void> deleteExpense(String id) async {
    // 1. Delete links in expense_margins first to avoid FK constraint error
    await _client.from('expense_margins').delete().eq('expense_id', id);

    // 2. Delete the expense
    await _client.from('expenses').delete().eq('id', id);
  }

  Future<List<MarginModel>> getRelatedMargins(String expenseId) async {
    final response = await _client
        .from('expense_margins')
        .select('margins(*)')
        .eq('expense_id', expenseId);

    return (response as List)
        .map((e) => MarginModel.fromJson(e['margins']))
        .toList();
  }
}
