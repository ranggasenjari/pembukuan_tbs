import 'dart:typed_data';

import '../models/bon_model.dart';
import '../models/factory_model.dart';
import '../models/nota_model.dart';
import '../models/relation_agent_model.dart';
import '../models/sub_nota_model.dart';
import '../models/vehicle_model.dart';

/// Kontrak repository bon yang dipakai layar UI.
/// Implementasi bisa remote (Supabase) atau offline-first (lokal + sinkron).
abstract class IBonRepository {
  Future<List<BonModel>> getBons({
    DateTime? startDate,
    DateTime? endDate,
    String? driverQuery,
    String? factoryId,
  });

  Future<BonModel> createBon(
    BonModel bon,
    Uint8List? imageBytes,
    String? fileName, {
    String? existingImageUrl,
  });

  Future<void> quickUpdateBon(String id, Map<String, dynamic> changes);

  Future<void> updateRaw(String id, Map<String, dynamic> data);

  Future<void> updateBon(BonModel bon);

  Future<void> deleteBon(String id);

  Future<Map<String, List<dynamic>>> getRelatedRecords(String bonId);

  Future<double> getLatestPrice();
}

/// Kontrak repository nota yang dipakai layar UI.
abstract class INotaRepository {
  Future<List<NotaModel>> getNotas({
    DateTime? startDate,
    DateTime? endDate,
    String? driverQuery,
    String? factoryId,
  });

  Future<NotaModel> createNota(NotaModel nota, List<String> bonIds);

  Future<void> updateNota(
    NotaModel nota,
    List<String> currentBonIds,
    List<String> newBonIds,
  );

  Future<void> deleteNota(String id);

  Future<String?> getNotaIdByBonId(String bonId);

  Future<NotaModel?> getNotaById(String id);

  Future<List<BonModel>> getNotaBons(String notaId);

  Future<void> updateNotaTotal(String notaId, double totalAmount);

  Future<NotaModel> mergeBonsIntoNota(
    List<String> bonIds, {
    String? relationAgentId,
  });
}

/// Kontrak repository pabrik. Operasi list/baca offline-capable,
/// operasi tulis hanya berjalan saat online.
abstract class IFactoryRepository {
  Future<List<FactoryModel>> getFactories({String? query});

  Future<FactoryModel> getFactory(String id);

  Future<void> createFactory(FactoryModel factory);

  Future<void> updateFactory(FactoryModel factory);

  Future<void> deleteFactory(String id);
}

/// Kontrak repository relasi/agen. Operasi list/baca offline-capable,
/// operasi tulis hanya berjalan saat online.
abstract class IRelationAgentRepository {
  Future<List<RelationAgentModel>> getRelationAgents({String? query});

  Future<RelationAgentModel> getRelationAgent(String id);

  Future<void> createRelationAgent(RelationAgentModel relationAgent);

  Future<void> updateRelationAgent(RelationAgentModel relationAgent);

  Future<void> deleteRelationAgent(String id);
}

/// Kontrak repository kendaraan. Operasi list/baca offline-capable,
/// operasi tulis hanya berjalan saat online.
abstract class IVehicleRepository {
  Future<List<VehicleModel>> getVehicles({String? query});

  Future<VehicleModel> getVehicle(String id);

  Future<List<PaymentRelationOption>> getPaymentRelationOptions();

  Future<void> createVehicle(VehicleModel vehicle);

  Future<void> updateVehicle(VehicleModel vehicle);

  Future<void> updateVehicleRelation(String vehicleId, String? relationId);

  Future<void> deleteVehicle(String id);
}

/// Kontrak repository sub nota.
/// Baca offline-capable; tulis offline-first (lokal + antrean sinkron).
abstract class ISubNotaRepository {
  Future<List<SubNotaModel>> getByBon(String bonId);

  Future<SubNotaModel> create({
    required String bonId,
    required String name,
    required int pricePerKg,
    int? netto2,
    String? notes,
  });

  Future<void> delete(String id);
}