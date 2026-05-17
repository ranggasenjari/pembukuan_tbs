import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/bon_repository.dart';
import '../repositories/nota_repository.dart';
import '../repositories/payment_repository.dart';
import '../services/pdf_service.dart';
import '../repositories/margin_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/deposit_repository.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final pdfServiceProvider = Provider<PdfService>((ref) {
  return PdfService();
});

final bonRepositoryProvider = Provider<BonRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return BonRepository(client);
});

final notaRepositoryProvider = Provider<NotaRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return NotaRepository(client);
});

final paymentRepositoryProvider = Provider<PaymentRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return PaymentRepository(client);
});

final marginRepositoryProvider = Provider<MarginRepository>((ref) {
  return MarginRepository(ref.watch(supabaseClientProvider));
});

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(supabaseClientProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return DashboardRepository(client);
});

final depositRepositoryProvider = Provider<DepositRepository>((ref) {
  return DepositRepository(ref.watch(supabaseClientProvider));
});

final dashboardStatsProvider = FutureProvider.autoDispose
    .family<DashboardStats, DateTimeRange>((ref, range) {
      final repo = ref.watch(dashboardRepositoryProvider);
      return repo.getDashboardStats(range.start, range.end);
    });

final bonRelatedRecordsProvider =
    FutureProvider.family<Map<String, List<dynamic>>, String>((ref, bonId) {
      final repo = ref.watch(bonRepositoryProvider);
      return repo.getRelatedRecords(bonId);
    });
