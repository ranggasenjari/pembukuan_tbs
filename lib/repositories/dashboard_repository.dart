import 'package:supabase_flutter/supabase_flutter.dart';

class FactoryBreakdown {
  final String? factoryId;
  final String name;
  final int count;
  final double tonnage;
  final double value;

  FactoryBreakdown({
    this.factoryId,
    required this.name,
    required this.count,
    required this.tonnage,
    required this.value,
  });
}

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

  // Fokus transaksi harian
  final double totalTonnage;
  final double totalTransactionValue;
  final double totalPayments;
  final List<FactoryBreakdown> factoryBreakdown;

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
    this.totalTonnage = 0,
    this.totalTransactionValue = 0,
    this.totalPayments = 0,
    this.factoryBreakdown = const [],
  });
}

class DashboardRepository {
  final SupabaseClient _client;

  DashboardRepository(this._client);

  Future<DashboardStats> getDashboardStats(DateTime start, DateTime end) async {
    final startIso = start.toIso8601String();
    final nextDayEndIso = DateTime.utc(end.year, end.month, end.day + 1).toIso8601String();

    // 1. Bons Stats (termasuk netto_2 + total + factory name untuk breakdown)
    final bonsResponse = await _client
        .from('bons')
        .select('id, status, factory_id, netto_2, total, factories(name)')
        .gte('bon_date', startIso)
        .lt('bon_date', nextDayEndIso);

    final bonsList = (bonsResponse as List).cast<Map<String, dynamic>>();
    final totalBons = bonsList.length;
    final ongoingBons = bonsList.where((b) => b['status'] != 'LUNAS').length;
    final finishedBons = bonsList.where((b) => b['status'] == 'LUNAS').length;

    double totalTonnage = 0;
    double totalTransactionValue = 0;
    final factoryMap = <String, FactoryBreakdown>{};
    for (final b in bonsList) {
      final netto = (b['netto_2'] as num?)?.toDouble() ?? 0.0;
      final value = (b['total'] as num?)?.toDouble() ?? 0.0;
      totalTonnage += netto;
      totalTransactionValue += value;
      final factoryId = b['factory_id']?.toString();
      final factories = b['factories'];
      final name = (factories is Map && factories.containsKey('name'))
          ? (factories['name']?.toString() ?? 'Tanpa Pabrik')
          : 'Tanpa Pabrik';
      final id = factoryId ?? '$name-';
      final entry = factoryMap.putIfAbsent(
        id,
        () => FactoryBreakdown(
          factoryId: factoryId,
          name: name,
          count: 0,
          tonnage: 0,
          value: 0,
        ),
      );
      factoryMap[id] = FactoryBreakdown(
        factoryId: factoryId,
        name: name,
        count: entry.count + 1,
        tonnage: entry.tonnage + netto,
        value: entry.value + value,
      );
    }
    final factoryBreakdown = factoryMap.values.toList()
      ..sort((a, b) => b.tonnage.compareTo(a.tonnage));

    // 2. Nota Timbangan Stats
    final notasResponse = await _client
        .from('notas')
        .select('id, status')
        .gte('invoice_date', startIso)
        .lt('invoice_date', nextDayEndIso);

    final notasList = (notasResponse as List).cast<Map<String, dynamic>>();
    final unpaidNotas = notasList.where((i) => i['status'] != 'LUNAS').length;
    final paidNotas = notasList.where((i) => i['status'] == 'LUNAS').length;

    // 3. Financial Stats (Payments & Margins)
    final paymentsResponse = await _client
        .from('payments')
        .select('amount_paid')
        .gte('payment_date', startIso)
        .lt('payment_date', nextDayEndIso);

    double totalPayments = 0;
    for (var p in (paymentsResponse as List)) {
      totalPayments += (p['amount_paid'] as num?)?.toDouble() ?? 0.0;
    }

    final marginsResponse = await _client
        .from('margins')
        .select('offtaker_amount')
        .gte('transaction_date', startIso)
        .lt('transaction_date', nextDayEndIso);

    double totalTransactions = 0;
    for (var m in (marginsResponse as List)) {
      totalTransactions += (m['offtaker_amount'] as num?)?.toDouble() ?? 0.0;
    }

    final double totalMargin = totalTransactions - totalPayments;

    // 4. Expense Stats
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

    // 5. Global Balance
    final allDepositsResponse = await _client.from('deposits').select('amount');
    int totalDeposits = 0;
    for (var d in (allDepositsResponse as List)) {
      totalDeposits += (d['amount'] as int);
    }

    final allPaymentsResponse = await _client
        .from('payments')
        .select('amount_paid');
    int totalPaymentsGlobal = 0;
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
      totalMyTransactions: totalPayments,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      currentBalance: currentBalance,
      totalTonnage: totalTonnage,
      totalTransactionValue: totalTransactionValue,
      totalPayments: totalPayments,
      factoryBreakdown: factoryBreakdown,
    );
  }
}