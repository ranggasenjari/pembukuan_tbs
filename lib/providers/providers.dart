import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../offline/hybrid_repositories.dart';
import '../offline/offline_coordinator.dart';
import '../repositories/payment_repository.dart';
import '../services/pdf_service.dart';
import '../repositories/margin_repository.dart';
import '../repositories/expense_repository.dart';
import '../repositories/dashboard_repository.dart';
import '../repositories/deposit_repository.dart';
import '../repositories/payment_relation_repository.dart';
import '../repositories/ocr_settings_repository.dart';
import '../services/ocr_service.dart';
import '../repositories/interfaces.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Koordinator offline/online dibuat sekali di `main` lalu di-override
/// lewat ProviderScope. Provider ini hanya jadi titik baca bersama.
final coordinatorProvider = Provider<SyncCoordinator>((ref) {
  throw StateError('coordinatorProvider belum di-override di main.');
});

final pdfServiceProvider = Provider<PdfService>((ref) {
  return PdfService();
});

final bonRepositoryProvider = Provider<IBonRepository>((ref) {
  return HybridBonRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(coordinatorProvider),
  );
});

final notaRepositoryProvider = Provider<INotaRepository>((ref) {
  return HybridNotaRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(coordinatorProvider),
  );
});

final subNotaRepositoryProvider = Provider<ISubNotaRepository>((ref) {
  return HybridSubNotaRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(coordinatorProvider),
  );
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

final relationAgentRepositoryProvider = Provider<IRelationAgentRepository>((
  ref,
) {
  return HybridRelationAgentRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(coordinatorProvider),
  );
});

final paymentRelationRepositoryProvider = Provider<PaymentRelationRepository>((
  ref,
) {
  return PaymentRelationRepository(ref.watch(supabaseClientProvider));
});

final factoryRepositoryProvider = Provider<IFactoryRepository>((ref) {
  return HybridFactoryRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(coordinatorProvider),
  );
});

final vehicleRepositoryProvider = Provider<IVehicleRepository>((ref) {
  return HybridVehicleRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(coordinatorProvider),
  );
});

final ocrSettingsRepositoryProvider = Provider<OcrSettingsRepository>((ref) {
  return OcrSettingsRepository(ref.watch(supabaseClientProvider));
});final ocrServiceProvider = Provider<OcrService>((ref) {
  return OcrService(ref.watch(supabaseClientProvider));
});

final ocrSettingsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(ocrSettingsRepositoryProvider).getSettings();
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
