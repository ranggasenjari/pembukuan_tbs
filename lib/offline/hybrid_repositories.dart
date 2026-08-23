import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/bon_model.dart';
import '../models/factory_model.dart';
import '../models/nota_model.dart';
import '../models/relation_agent_model.dart';
import '../models/sub_nota_model.dart';
import '../models/vehicle_model.dart';
import '../repositories/bon_repository.dart';
import '../repositories/factory_repository.dart';
import '../repositories/interfaces.dart';
import '../repositories/nota_repository.dart';
import '../repositories/relation_agent_repository.dart';
import '../repositories/sub_nota_repository.dart';
import '../repositories/vehicle_repository.dart';
import 'offline_coordinator.dart';
import 'offline_repositories.dart';

/// Alur offline-first untuk data bon:
/// - Tulis: simpan lokal + antrean, lalu dorong ke cloud di background saat online.
/// - Baca: dari cache lokal (disegarkan oleh koordinator saat online);
///   bila belum ada database lokal (mode offline belum diaktifkan), baca dari cloud.
class HybridBonRepository implements IBonRepository {
  HybridBonRepository(SupabaseClient client, this._coordinator)
      : _remote = BonRepository(client);

  final SyncCoordinator _coordinator;
  final BonRepository _remote;

  OfflineBonRepository? _local() {
    final db = _coordinator.db;
    return db == null ? null : OfflineBonRepository(db);
  }

  void _sync() => unawaited(_coordinator.syncNow());

  @override
  Future<List<BonModel>> getBons({
    DateTime? startDate,
    DateTime? endDate,
    String? driverQuery,
    String? factoryId,
  }) {
    final local = _local();
    if (local != null) {
      return local.getBons(
        startDate: startDate,
        endDate: endDate,
        driverQuery: driverQuery,
        factoryId: factoryId,
      );
    }
    return _remote.getBons(
      startDate: startDate,
      endDate: endDate,
      driverQuery: driverQuery,
      factoryId: factoryId,
    );
  }

  @override
  Future<BonModel> createBon(
    BonModel bon,
    Uint8List? imageBytes,
    String? fileName, {
    String? existingImageUrl,
  }) async {
    final local = _local();
    if (_coordinator.online) {
      final result = await _remote.createBon(
        bon,
        imageBytes,
        fileName,
        existingImageUrl: existingImageUrl,
      );
      _sync();
      return result;
    }
    if (local != null) {
      final result = await local.createBon(
        bon,
        imageBytes,
        fileName,
        existingImageUrl: existingImageUrl,
      );
      _sync();
      return result;
    }
    return _remote.createBon(
      bon,
      imageBytes,
      fileName,
      existingImageUrl: existingImageUrl,
    );
  }

  @override
  Future<void> quickUpdateBon(String id, Map<String, dynamic> changes) async {
    final local = _local();
    if (_coordinator.online) {
      await _remote.quickUpdateBon(id, changes);
      _sync();
      return;
    }
    if (local != null) {
      await local.quickUpdateBon(id, changes);
      _sync();
      return;
    }
    await _remote.quickUpdateBon(id, changes);
  }

  @override
  Future<void> updateRaw(String id, Map<String, dynamic> data) async {
    final local = _local();
    if (_coordinator.online) {
      await _remote.updateRaw(id, data);
      _sync();
      return;
    }
    if (local != null) {
      await local.updateRaw(id, data);
      _sync();
      return;
    }
    await _remote.updateRaw(id, data);
  }

  @override
  Future<void> updateBon(BonModel bon) async {
    final local = _local();
    if (_coordinator.online) {
      await _remote.updateBon(bon);
      _sync();
      return;
    }
    if (local != null) {
      await local.updateBon(bon);
      _sync();
      return;
    }
    await _remote.updateBon(bon);
  }

  @override
  Future<void> deleteBon(String id) async {
    final local = _local();
    if (_coordinator.online) {
      await _remote.deleteBon(id);
      _sync();
      return;
    }
    if (local != null) {
      await local.deleteBon(id);
      _sync();
      return;
    }
    await _remote.deleteBon(id);
  }

  @override
  Future<Map<String, List<dynamic>>> getRelatedRecords(String bonId) {
    final local = _local();
    return local != null ? local.getRelatedRecords(bonId) : _remote.getRelatedRecords(bonId);
  }

  @override
  Future<double> getLatestPrice() {
    final local = _local();
    return local != null ? local.getLatestPrice() : _remote.getLatestPrice();
  }
}

/// Alur offline-first untuk data nota.
class HybridNotaRepository implements INotaRepository {
  HybridNotaRepository(SupabaseClient client, this._coordinator)
      : _remote = NotaRepository(client);

  final SyncCoordinator _coordinator;
  final NotaRepository _remote;

  OfflineNotaRepository? _local() {
    final db = _coordinator.db;
    return db == null ? null : OfflineNotaRepository(db);
  }

  void _sync() => unawaited(_coordinator.syncNow());

  @override
  Future<List<NotaModel>> getNotas({
    DateTime? startDate,
    DateTime? endDate,
    String? driverQuery,
    String? factoryId,
  }) {
    final local = _local();
    if (local != null) {
      return local.getNotas(
        startDate: startDate,
        endDate: endDate,
        driverQuery: driverQuery,
        factoryId: factoryId,
      );
    }
    return _remote.getNotas(
      startDate: startDate,
      endDate: endDate,
      driverQuery: driverQuery,
      factoryId: factoryId,
    );
  }

  @override
  Future<NotaModel> createNota(NotaModel nota, List<String> bonIds) async {
    final local = _local();
    if (_coordinator.online) {
      final result = await _remote.createNota(nota, bonIds);
      _sync();
      return result;
    }
    if (local != null) {
      final result = await local.createNota(nota, bonIds);
      _sync();
      return result;
    }
    return _remote.createNota(nota, bonIds);
  }

  @override
  Future<void> updateNota(
    NotaModel nota,
    List<String> currentBonIds,
    List<String> newBonIds,
  ) async {
    final local = _local();
    if (_coordinator.online) {
      await _remote.updateNota(nota, currentBonIds, newBonIds);
      _sync();
      return;
    }
    if (local != null) {
      await local.updateNota(nota, currentBonIds, newBonIds);
      _sync();
      return;
    }
    await _remote.updateNota(nota, currentBonIds, newBonIds);
  }

  @override
  Future<void> deleteNota(String id) async {
    final local = _local();
    if (_coordinator.online) {
      await _remote.deleteNota(id);
      _sync();
      return;
    }
    if (local != null) {
      await local.deleteNota(id);
      _sync();
      return;
    }
    await _remote.deleteNota(id);
  }

  @override
  Future<String?> getNotaIdByBonId(String bonId) {
    final local = _local();
    return local != null ? local.getNotaIdByBonId(bonId) : _remote.getNotaIdByBonId(bonId);
  }

  @override
  Future<NotaModel?> getNotaById(String id) {
    final local = _local();
    return local != null ? local.getNotaById(id) : _remote.getNotaById(id);
  }

  @override
  Future<List<BonModel>> getNotaBons(String notaId) {
    final local = _local();
    return local != null ? local.getNotaBons(notaId) : _remote.getNotaBons(notaId);
  }

  @override
  Future<void> updateNotaTotal(String notaId, double totalAmount) async {
    final local = _local();
    if (_coordinator.online) {
      await _remote.updateNotaTotal(notaId, totalAmount);
      _sync();
      return;
    }
    if (local != null) {
      await local.updateNotaTotal(notaId, totalAmount);
      _sync();
      return;
    }
    await _remote.updateNotaTotal(notaId, totalAmount);
  }

  @override
  Future<NotaModel> mergeBonsIntoNota(
    List<String> bonIds, {
    String? relationAgentId,
  }) async {
    final local = _local();
    if (_coordinator.online) {
      final result = await _remote.mergeBonsIntoNota(bonIds, relationAgentId: relationAgentId);
      _sync();
      return result;
    }
    if (local != null) {
      final result = await local.mergeBonsIntoNota(bonIds, relationAgentId: relationAgentId);
      _sync();
      return result;
    }
    return _remote.mergeBonsIntoNota(bonIds, relationAgentId: relationAgentId);
  }
}

/// Alur offline-first untuk sub nota.
class HybridSubNotaRepository implements ISubNotaRepository {
  HybridSubNotaRepository(SupabaseClient client, this._coordinator)
      : _remote = SubNotaRepository(client);

  final SyncCoordinator _coordinator;
  final SubNotaRepository _remote;

  OfflineSubNotaRepository? _local() {
    final db = _coordinator.db;
    return db == null ? null : OfflineSubNotaRepository(db);
  }

  void _sync() => unawaited(_coordinator.syncNow());

  @override
  Future<List<SubNotaModel>> getByBon(String bonId) {
    final local = _local();
    if (local != null) return local.getByBon(bonId);
    return _remote.getByBon(bonId);
  }

  @override
  Future<SubNotaModel> create({
    required String bonId,
    required String name,
    required int pricePerKg,
    int? netto2,
    String? notes,
  }) async {
    final local = _local();
    if (_coordinator.online) {
      final result = await _remote.create(
        bonId: bonId,
        name: name,
        pricePerKg: pricePerKg,
        netto2: netto2,
        notes: notes,
      );
      _sync();
      return result;
    }
    if (local != null) {
      final result = await local.create(
        bonId: bonId,
        name: name,
        pricePerKg: pricePerKg,
        netto2: netto2,
        notes: notes,
      );
      _sync();
      return result;
    }
    return _remote.create(
      bonId: bonId,
      name: name,
      pricePerKg: pricePerKg,
      netto2: netto2,
      notes: notes,
    );
  }

  @override
  Future<void> delete(String id) async {
    final local = _local();
    if (_coordinator.online) {
      await _remote.delete(id);
      _sync();
      return;
    }
    if (local != null) {
      await local.delete(id);
      _sync();
      return;
    }
    await _remote.delete(id);
  }
}

/// Data pabrik: baca dari cache lokal saat tersedia; tulis hanya saat online.
class HybridFactoryRepository implements IFactoryRepository {
  HybridFactoryRepository(SupabaseClient client, this._coordinator)
      : _remote = FactoryRepository(client);

  final SyncCoordinator _coordinator;
  final FactoryRepository _remote;

  OfflineMasterRepository? _masters() {
    final db = _coordinator.db;
    return db == null ? null : OfflineMasterRepository(db);
  }

  @override
  Future<List<FactoryModel>> getFactories({String? query}) {
    final masters = _masters();
    if (masters != null) return masters.factories(query: query);
    return _remote.getFactories(query: query);
  }

  @override
  Future<FactoryModel> getFactory(String id) async {
    if (_coordinator.online) return _remote.getFactory(id);
    final masters = _masters();
    if (masters != null) {
      final cached = await masters.factoryById(id);
      if (cached != null) return cached;
    }
    return _remote.getFactory(id);
  }

  @override
  Future<void> createFactory(FactoryModel factory) async {
    _ensureOnline();
    await _remote.createFactory(factory);
  }

  @override
  Future<void> updateFactory(FactoryModel factory) async {
    _ensureOnline();
    await _remote.updateFactory(factory);
  }

  @override
  Future<void> deleteFactory(String id) async {
    _ensureOnline();
    await _remote.deleteFactory(id);
  }

  void _ensureOnline() {
    if (!_coordinator.online) {
      throw StateError('Kelola pabrik membutuhkan koneksi internet.');
    }
  }
}

/// Data relasi/agen: baca dari cache lokal saat tersedia; tulis hanya saat online.
class HybridRelationAgentRepository implements IRelationAgentRepository {
  HybridRelationAgentRepository(SupabaseClient client, this._coordinator)
      : _remote = RelationAgentRepository(client);

  final SyncCoordinator _coordinator;
  final RelationAgentRepository _remote;

  OfflineMasterRepository? _masters() {
    final db = _coordinator.db;
    return db == null ? null : OfflineMasterRepository(db);
  }

  @override
  Future<List<RelationAgentModel>> getRelationAgents({String? query}) {
    final masters = _masters();
    if (masters != null) return masters.relations(query: query);
    return _remote.getRelationAgents(query: query);
  }

  @override
  Future<RelationAgentModel> getRelationAgent(String id) async {
    if (_coordinator.online) return _remote.getRelationAgent(id);
    final masters = _masters();
    if (masters != null) {
      final cached = await masters.relationById(id);
      if (cached != null) return cached;
    }
    return _remote.getRelationAgent(id);
  }

  @override
  Future<void> createRelationAgent(RelationAgentModel relationAgent) async {
    _ensureOnline();
    await _remote.createRelationAgent(relationAgent);
  }

  @override
  Future<void> updateRelationAgent(RelationAgentModel relationAgent) async {
    _ensureOnline();
    await _remote.updateRelationAgent(relationAgent);
  }

  @override
  Future<void> deleteRelationAgent(String id) async {
    _ensureOnline();
    await _remote.deleteRelationAgent(id);
  }

  void _ensureOnline() {
    if (!_coordinator.online) {
      throw StateError('Kelola relasi/agen membutuhkan koneksi internet.');
    }
  }
}

/// Data kendaraan: baca dari cache lokal saat tersedia; tulis hanya saat online.
class HybridVehicleRepository implements IVehicleRepository {
  HybridVehicleRepository(SupabaseClient client, this._coordinator)
      : _remote = VehicleRepository(client);

  final SyncCoordinator _coordinator;
  final VehicleRepository _remote;

  OfflineMasterRepository? _masters() {
    final db = _coordinator.db;
    return db == null ? null : OfflineMasterRepository(db);
  }

  @override
  Future<List<VehicleModel>> getVehicles({String? query}) {
    final masters = _masters();
    if (masters != null) return masters.vehiclesModels(query: query);
    return _remote.getVehicles(query: query);
  }

  @override
  Future<VehicleModel> getVehicle(String id) async {
    final masters = _masters();
    if (masters != null) {
      final cached = await masters.vehicleById(id);
      if (cached != null) return cached;
    }
    return _remote.getVehicle(id);
  }

  @override
  Future<List<PaymentRelationOption>> getPaymentRelationOptions() {
    final masters = _masters();
    if (masters != null) return masters.paymentRelationOptions();
    return _remote.getPaymentRelationOptions();
  }

  @override
  Future<void> createVehicle(VehicleModel vehicle) async {
    _ensureOnline();
    await _remote.createVehicle(vehicle);
  }

  @override
  Future<void> updateVehicle(VehicleModel vehicle) async {
    _ensureOnline();
    await _remote.updateVehicle(vehicle);
  }

  @override
  Future<void> updateVehicleRelation(String vehicleId, String? relationId) async {
    _ensureOnline();
    await _remote.updateVehicleRelation(vehicleId, relationId);
  }

  @override
  Future<void> deleteVehicle(String id) async {
    _ensureOnline();
    await _remote.deleteVehicle(id);
  }

  void _ensureOnline() {
    if (!_coordinator.online) {
      throw StateError('Kelola kendaraan membutuhkan koneksi internet.');
    }
  }
}