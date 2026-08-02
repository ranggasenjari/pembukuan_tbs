import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardStats {
  final int totalBons;
  final int ongoingBons;
  final int finishedBons;
  final int unpaidNotas;
  final int paidNotas;
  final double totalMargin;
  final double totalTransactions;
  final double totalMyTransactions;
  final double totalExpenses;
  final double netProfit;
  final int currentBalance;

  DashboardStats({
    required this.totalBons,
    required this.ongoingBons,
    required this.finishedBons,
    required this.unpaidNotas,
    required this.paidNotas,
    required this.totalMargin,
    required this.totalTransactions,
    required this.totalMyTransactions,
    required this.totalExpenses,
    required this.netProfit,
    required this.currentBalance,
  });
}

class DashboardRepository {
  final SupabaseClient _client;

  DashboardRepository(this._client);

  Future<DashboardStats> getDashboardStats(DateTime start, DateTime end) async {
    final startIso = start.toIso8601String();
    final nextDayEndIso = DateTime.utc(end.year, end.month, end.day + 1).toIso8601String();

    // 1. Bons Stats
    final bonsResponse = await _client
        .from('bons')
        .select('id, status')
        .gte('bon_date', startIso)
        .lt('bon_date', nextDayEndIso);

    final totalBons = (bonsResponse as List).length;
    final ongoingBons = (bonsResponse)
        .where((b) => b['status'] != 'LUNAS')
        .length;
    final finishedBons = (bonsResponse)
        .where((b) => b['status'] == 'LUNAS')
        .length;

    // 2. Nota Timbangan Stats
    final notasResponse = await _client
        .from('notas')
        .select('id, status')
        .gte('invoice_date', startIso)
        .lt('invoice_date', nextDayEndIso);

    final unpaidNotas = (notasResponse as List)
        .where((i) => i['status'] != 'LUNAS')
        .length;
    final paidNotas = (notasResponse)
        .where((i) => i['status'] == 'LUNAS')
        .length;

    // 3. Financial Stats (Payments & Margins)
    // Sum all payments in the range to get "Total My Transactions"
    final paymentsResponse = await _client
        .from('payments')
        .select('amount_paid')
        .gte('payment_date', startIso)
        .lt('payment_date', nextDayEndIso);

    double totalMyTransactions = 0;
    for (var p in (paymentsResponse as List)) {
      totalMyTransactions += (p['amount_paid'] as num?)?.toDouble() ?? 0.0;
    }

    // Sum all margin offtaker amounts in the range to get "Total Transactions"
    final marginsResponse = await _client
        .from('margins')
        .select('offtaker_amount')
        .gte('transaction_date', startIso)
        .lt('transaction_date', nextDayEndIso);

    double totalTransactions = 0;
    for (var m in (marginsResponse as List)) {
      totalTransactions += (m['offtaker_amount'] as num?)?.toDouble() ?? 0.0;
    }

    // Margin is the difference between what we got from the offtaker
    // and what we actually paid out to suppliers.
    final double totalMargin = totalTransactions - totalMyTransactions;

    // 4. Expense Stats (Profit Sharing / Operasional)
    final expensesResponse = await _client
        .from('expenses')
        .select('amount')
        .gte('expense_date', startIso)
        .lt('expense_date', nextDayEndIso);

    double totalExpenses = 0;
    for (var e in (expensesResponse as List)) {
      totalExpenses += (e['amount'] as num?)?.toDouble() ?? 0.0;
    }

    final double netProfit = totalMargin - totalExpenses;

    // 5. Global Balance (Saldo Tersedia)
    // IMPORTANT: This should probably be ALL time, not just the date range?
    // User asked for "Saldo pada dashboard". Usually means Balance NOW.
    // I will fetch GLOBAL totals for Balance.

    // Check if we can use RPC or simple select. Using simple select sum for now.
    // Note: This logic duplicates what is in Saldo/Payment Repository but keeps Dashboard independent or we could import them?
    // To keep it clean in one call, I'll do it here. Or better, reuse if possible.
    // But repos are not singletons injected here easily without Ref.
    // I'll re-implement the sum logic here for simplicity and performance (can optimize later).

    final allDepositsResponse = await _client.from('deposits').select('amount');
    int totalDeposits = 0;
    for (var d in (allDepositsResponse as List)) {
      totalDeposits += (d['amount'] as int);
    }

    final allPaymentsResponse = await _client
        .from('payments')
        .select('amount_paid');
    int totalPaymentsGlobal =
        0; // Distinct from totalMyTransactions which is filtered by date
    for (var p in (allPaymentsResponse as List)) {
      totalPaymentsGlobal += (p['amount_paid'] as int);
    }

    final int currentBalance = totalDeposits - totalPaymentsGlobal;

    return DashboardStats(
      totalBons: totalBons,
      ongoingBons: ongoingBons,
      finishedBons: finishedBons,
      unpaidNotas: unpaidNotas,
      paidNotas: paidNotas,
      totalMargin: totalMargin,
      totalTransactions: totalTransactions,
      totalMyTransactions: totalMyTransactions,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      currentBalance: currentBalance,
    );
  }
}
