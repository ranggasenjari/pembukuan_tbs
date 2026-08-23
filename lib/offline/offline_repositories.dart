import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../core/enums.dart';
import '../models/bon_model.dart';
import '../models/factory_model.dart';
import '../models/nota_model.dart';
import '../models/relation_agent_model.dart';
import '../models/sub_nota_model.dart';
import '../models/vehicle_model.dart';
import '../repositories/interfaces.dart';
import 'offline_database.dart';

class OfflineBonRepository implements IBonRepository {
  OfflineBonRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final OfflineDatabase _db;
  final Uuid _uuid;

  @override
  Future<List<BonModel>> getBons({
    DateTime? startDate,
    DateTime? endDate,
    String? driverQuery,
    String? factoryId,
  }) async {
    final query = driverQuery?.trim().toUpperCase();
    return (await _db.bons()).map((row) => BonModel.fromJson(row.payload)).where((bon) {
      if (startDate != null && bon.bonDate.isBefore(startDate)) return false;
      if (endDate != null && bon.bonDate.isAfter(endDate.add(const Duration(days: 1)))) return false;
      if (factoryId != null && factoryId.isNotEmpty && bon.factoryId != factoryId) return false;
      if (query != null && query.isNotEmpty) {
        final text = '${bon.driverName} ${bon.plateNumber} ${bon.relationName}'.toUpperCase();
        if (!text.contains(query)) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<BonModel> createBon(BonModel bon, Uint8List? imageBytes, String? fileName,
      {String? existingImageUrl}) async {
    final imagePath = imageBytes == null ? null : await _copyAttachment(bon.id, imageBytes, fileName);
    final payload = _bonPayload(bon, imageUrl: existingImageUrl);
    await _db.saveBon(payload: payload, syncState: 'pending', imagePath: imagePath);
    await _enqueueBon(payload, imagePath: imagePath);
    return BonModel.fromJson(payload);
  }

  @override
  Future<void> updateBon(BonModel bon) async {
    final existing = await _db.bon(bon.id);
    if (existing == null) throw StateError('Bon lokal tidak ditemukan.');
    if (BonModel.fromJson(existing.payload).status == PaymentStatus.lunas) {
      throw StateError('Bon sudah lunas, tidak dapat diedit.');
    }
    final payload = _bonPayload(bon, imageUrl: existing.payload['image_url']?.toString());
    await _db.saveBon(
      payload: payload,
      syncState: 'pending',
      imagePath: existing.imagePath,
      notaId: existing.notaId,
      remoteVersion: existing.remoteVersion,
    );
    await _enqueueBon(payload, imagePath: existing.imagePath, baseVersion: existing.remoteVersion);
  }

  @override
  Future<void> quickUpdateBon(String id, Map<String, dynamic> changes) async {
    final row = await _db.bon(id);
    if (row == null) throw StateError('Bon lokal tidak ditemukan.');
    if (BonModel.fromJson(row.payload).status == PaymentStatus.lunas) {
      throw StateError('Bon sudah lunas, tidak dapat diedit.');
    }
    final payload = Map<String, dynamic>.from(row.payload)..addAll(changes);
    await _db.saveBon(
      payload: payload,
      syncState: 'pending',
      imagePath: row.imagePath,
      notaId: row.notaId,
      remoteVersion: row.remoteVersion,
    );
    await _enqueueBon(payload, imagePath: row.imagePath, baseVersion: row.remoteVersion);
  }

  @override
  Future<void> updateRaw(String id, Map<String, dynamic> data) async {
    final row = await _db.bon(id);
    if (row == null) return;
    final payload = Map<String, dynamic>.from(row.payload)..addAll(data);
    await _db.saveBon(
      payload: payload,
      syncState: 'pending',
      imagePath: row.imagePath,
      notaId: row.notaId,
      remoteVersion: row.remoteVersion,
    );
    await _enqueueBon(payload, imagePath: row.imagePath, baseVersion: row.remoteVersion);
  }

  @override
  Future<void> deleteBon(String id) async {
    final row = await _db.bon(id);
    if (row == null) return;
    final payload = row.payload;
    await _db.purgeSubNotasForBon(id);
    if (row.remoteVersion == null) {
      await _db.deleteOperationWhereEntity('bon', id);
      await _db.deleteBon(id);
      if (row.imagePath != null) await File(row.imagePath!).delete().catchError((_) => File(row.imagePath!));
      return;
    }
    await _db.enqueue(OfflineOperation(
      id: _uuid.v4(),
      entityType: 'bon_delete',
      entityId: id,
      payload: {'bon_id': id, 'base_version': row.remoteVersion},
    ));
    await _db.saveBon(payload: payload, syncState: 'pending_delete', imagePath: row.imagePath, remoteVersion: row.remoteVersion);
  }

  @override
  Future<Map<String, List<dynamic>>> getRelatedRecords(String bonId) async {
    final row = await _db.bon(bonId);
    final notaId = row?.notaId;
    final notas = <NotaModel>[];
    if (notaId != null) {
      final notaRow = await _db.nota(notaId);
      if (notaRow != null) notas.add(NotaModel.fromJson(notaRow.payload));
    }
    // Pembayaran tidak disimpan offline; kosongkan.
    return {'notas': notas, 'payments': <dynamic>[]};
  }

  @override
  Future<double> getLatestPrice() async {
    final bons = await getBons();
    return bons.isEmpty ? 0 : bons.first.price;
  }

  Future<void> _enqueueBon(Map<String, dynamic> payload, {String? imagePath, int? baseVersion}) {
    return _db.enqueue(OfflineOperation(
      id: _uuid.v4(),
      entityType: 'bon',
      entityId: payload['id'] as String,
      attachmentPath: imagePath,
      payload: {'bon': payload, if (baseVersion != null) 'base_version': baseVersion},
    ));
  }

  Future<String> _copyAttachment(String bonId, Uint8List bytes, String? filename) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'offline', _db.userId, 'attachments', '$bonId-${filename ?? 'bon.jpg'}'));
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}

class OfflineNotaRepository implements INotaRepository {
  OfflineNotaRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final OfflineDatabase _db;
  final Uuid _uuid;

  @override
  Future<List<NotaModel>> getNotas({DateTime? startDate, DateTime? endDate, String? driverQuery, String? factoryId}) async {
    final rows = await _db.notas();
    final driver = driverQuery?.trim().toUpperCase();
    List<Map<String, dynamic>> bonPayloads = const [];
    if (driver != null && driver.isNotEmpty ||
        factoryId != null && factoryId.isNotEmpty) {
      bonPayloads = (await _db.bons()).map((r) => r.payload).toList();
    }

    final result = <NotaModel>[];
    for (final row in rows) {
      final payload = row.payload;
      final nota = NotaModel.fromJson(payload);
      if (startDate != null && nota.notaDate.isBefore(startDate)) continue;
      if (endDate != null && nota.notaDate.isAfter(endDate.add(const Duration(days: 1)))) continue;

      final bonIds = (payload['bon_ids'] as List? ?? const []).map((e) => e.toString()).toSet();
      var matches = true;
      if (driver != null && driver.isNotEmpty || factoryId != null && factoryId.isNotEmpty) {
        matches = false;
        for (final b in bonPayloads) {
          if (!bonIds.contains(b['id'])) continue;
          final text = '${b['driver_name']} ${b['plate_number']}'.toUpperCase();
          final driverOk = driver == null || driver.isEmpty || text.contains(driver);
          final factoryOk = factoryId == null || factoryId.isEmpty || b['factory_id'] == factoryId;
          if (driverOk && factoryOk) {
            matches = true;
            break;
          }
        }
      }
      if (matches) result.add(nota);
    }
    return result;
  }

  @override
  Future<NotaModel> createNota(NotaModel nota, List<String> bonIds) async {
    final payload = _notaPayload(nota, bonIds);
    await _db.saveNota(payload: payload, syncState: 'pending');
    await _assignBons(nota.id, bonIds, PaymentStatus.tertagih);
    await _enqueue(payload);
    return NotaModel.fromJson(payload);
  }

  @override
  Future<void> updateNota(NotaModel nota, List<String> currentBonIds, List<String> newBonIds) async {
    final row = await _db.nota(nota.id);
    final payload = _notaPayload(nota, newBonIds);
    await _assignBons(nota.id, currentBonIds.where((id) => !newBonIds.contains(id)).toList(), PaymentStatus.belumDibayar, clearNota: true);
    await _assignBons(nota.id, newBonIds, PaymentStatus.tertagih);
    await _db.saveNota(payload: payload, syncState: 'pending', remoteVersion: row?.remoteVersion);
    await _enqueue(payload, baseVersion: row?.remoteVersion);
  }

  @override
  Future<void> deleteNota(String id) async {
    final row = await _db.nota(id);
    if (row == null) return;
    final ids = (row.payload['bon_ids'] as List? ?? const []).map((e) => e.toString()).toList();
    await _assignBons(id, ids, PaymentStatus.belumDibayar, clearNota: true);
    await _db.deleteNota(id);
    await _db.deleteOperationWhereEntity('nota', id);
  }

  @override
  Future<List<BonModel>> getNotaBons(String notaId) async {
    return (await _db.bons(notaId: notaId)).map((row) => BonModel.fromJson(row.payload)).toList();
  }

  @override
  Future<String?> getNotaIdByBonId(String bonId) async => (await _db.bon(bonId))?.notaId;

  @override
  Future<NotaModel?> getNotaById(String id) async {
    final row = await _db.nota(id);
    if (row == null) return null;
    return NotaModel.fromJson(row.payload);
  }

  @override
  Future<void> updateNotaTotal(String notaId, double totalAmount) async {
    final row = await _db.nota(notaId);
    if (row == null) return;
    final payload = Map<String, dynamic>.from(row.payload)..['total_amount'] = totalAmount.toInt();
    await _db.saveNota(payload: payload, syncState: 'pending', remoteVersion: row.remoteVersion);
    await _enqueue(payload, baseVersion: row.remoteVersion);
  }

  @override
  Future<NotaModel> mergeBonsIntoNota(
    List<String> bonIds, {
    String? relationAgentId,
  }) async {
    final ids = bonIds.toSet().toList();
    if (ids.length < 2) {
      throw Exception('Pilih minimal dua bon untuk digabung.');
    }

    final bons = <BonModel>[];
    for (final id in ids) {
      final row = await _db.bon(id);
      if (row == null) throw Exception('Ada bon yang tidak ditemukan.');
      final bon = BonModel.fromJson(row.payload);
      if (bon.status == PaymentStatus.lunas) {
        throw Exception('Bon LUNAS tidak dapat digabung.');
      }
      if (bon.status == PaymentStatus.tertagih || row.notaId != null) {
        throw Exception('Bon sudah masuk nota, keluarkan terlebih dahulu.');
      }
      bons.add(bon);
    }

    final relIds = bons.map((b) => b.relationAgentId).where((id) => id != null && id.isNotEmpty).toSet().toList();
    final relNames = bons.map((b) => b.relationName).where((name) => name != null && name.isNotEmpty).toSet().toList();

    String? relId = relationAgentId;
    String? relName;
    if (relationAgentId != null && relationAgentId.isNotEmpty) {
      relId = relationAgentId;
    } else if (relIds.length == 1) {
      relId = relIds.first;
    } else if (relNames.length == 1) {
      relName = relNames.first;
    } else {
      throw Exception('Relasi antar bon berbeda. Pilih relasi untuk nota gabungan.');
    }

    final total = bons.fold<double>(0, (sum, bon) => sum + bon.total);
    final now = DateTime.now();
    final nota = NotaModel(
      id: _uuid.v4(),
      notaNumber: 'NOTA-${now.millisecondsSinceEpoch}',
      notaDate: now,
      totalAmount: total,
      status: PaymentStatus.tertagih,
      relationAgentId: relId,
      recipientName: relName ?? relId,
      createdAt: now,
      updatedAt: now,
    );
    await createNota(nota, ids);
    return nota;
  }

  Future<void> _assignBons(String notaId, List<String> ids, PaymentStatus status, {bool clearNota = false}) async {
    for (final id in ids) {
      final row = await _db.bon(id);
      if (row == null) continue;
      final payload = Map<String, dynamic>.from(row.payload)..['status'] = status.value;
      await _db.saveBon(
        payload: payload,
        syncState: row.syncState,
        imagePath: row.imagePath,
        notaId: clearNota ? null : notaId,
        remoteVersion: row.remoteVersion,
      );
    }
  }

  Future<void> _enqueue(Map<String, dynamic> payload, {int? baseVersion}) => _db.enqueue(
        OfflineOperation(
          id: _uuid.v4(),
          entityType: 'nota',
          entityId: payload['id'] as String,
          payload: {'nota': payload, if (baseVersion != null) 'base_version': baseVersion},
        ),
      );
}

class OfflineSubNotaRepository implements ISubNotaRepository {
  OfflineSubNotaRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final OfflineDatabase _db;
  final Uuid _uuid;

  @override
  Future<List<SubNotaModel>> getByBon(String bonId) async {
    return (await _db.subNotas(bonId))
        .map((row) => SubNotaModel.fromJson(row.payload))
        .toList();
  }

  @override
  Future<SubNotaModel> create({
    required String bonId,
    required String name,
    required int pricePerKg,
    int? netto2,
    String? notes,
  }) async {
    final effectiveNetto2 = netto2 ?? await _bonNetto2(bonId);
    final payload = <String, dynamic>{
      'id': _uuid.v4(),
      'bon_id': bonId,
      'name': name.trim().toUpperCase(),
      'price_per_kg': pricePerKg,
      'netto_2': effectiveNetto2,
      'amount': effectiveNetto2 * pricePerKg,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'sync_version': null,
    };
    await _db.saveSubNota(payload: payload, syncState: 'pending');
    await _enqueue(payload);
    return SubNotaModel.fromJson(payload);
  }

  @override
  Future<void> delete(String id) async {
    final row = await _db.subNota(id);
    if (row == null) return;
    if (row.remoteVersion == null) {
      await _db.deleteOperationWhereEntity('sub_nota', id);
      await _db.deleteSubNota(id);
      return;
    }
    await _db.enqueue(OfflineOperation(
      id: _uuid.v4(),
      entityType: 'sub_nota_delete',
      entityId: id,
      payload: {'sub_nota_id': id},
    ));
    await _db.saveSubNota(
      payload: row.payload,
      syncState: 'pending_delete',
      remoteVersion: row.remoteVersion,
    );
  }

  Future<int> _bonNetto2(String bonId) async {
    final row = await _db.bon(bonId);
    if (row != null) {
      return (row.payload['netto_2'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<void> _enqueue(Map<String, dynamic> payload) => _db.enqueue(
        OfflineOperation(
          id: _uuid.v4(),
          entityType: 'sub_nota',
          entityId: payload['id'] as String,
          payload: {'sub_nota': payload},
        ),
      );
}

class OfflineMasterRepository {
  OfflineMasterRepository(this._db);
  final OfflineDatabase _db;

  Future<List<FactoryModel>> factories({String? query}) async {
    final rows = await _db.masters('factories');
    final types = await _db.masters('factory_spsi_types');
    final prices = await _db.masters('factory_prices');
    return rows.map((row) {
      final data = Map<String, dynamic>.from(row)
        ..['factory_spsi_types'] = types.where((x) => x['factory_id'] == row['id']).toList()
        ..['factory_prices'] = prices.where((x) => x['factory_id'] == row['id']).toList();
      return FactoryModel.fromJson(data);
    }).where((factory) => query == null || query.isEmpty || factory.name.toUpperCase().contains(query.toUpperCase())).toList();
  }

  Future<FactoryModel?> factoryById(String id) async {
    final rows = await _db.masters('factories');
    final types = await _db.masters('factory_spsi_types');
    final prices = await _db.masters('factory_prices');
    for (final row in rows) {
      if (row['id'] == id) {
        return FactoryModel.fromJson(
          Map<String, dynamic>.from(row)
            ..['factory_spsi_types'] = types
                .where((x) => x['factory_id'] == id)
                .toList()
            ..['factory_prices'] = prices
                .where((x) => x['factory_id'] == id)
                .toList(),
        );
      }
    }
    return null;
  }

  Future<List<RelationAgentModel>> relations({String? query}) async {
    final rows = await _db.masters('relation_agents');
    final accounts = await _db.masters('relation_agent_accounts');
    return rows.map((row) => RelationAgentModel.fromJson({
          ...row,
          'relation_agent_accounts': accounts.where((x) => x['relation_agent_id'] == row['id']).toList(),
        })).where((relation) => query == null || query.isEmpty || relation.name.toUpperCase().contains(query.toUpperCase())).toList();
  }

  Future<RelationAgentModel?> relationById(String id) async {
    final rows = await _db.masters('relation_agents');
    final accounts = await _db.masters('relation_agent_accounts');
    for (final row in rows) {
      if (row['id'] == id) {
        return RelationAgentModel.fromJson(
          Map<String, dynamic>.from(row)
            ..['relation_agent_accounts'] = accounts
                .where((x) => x['relation_agent_id'] == id)
                .toList(),
        );
      }
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> vehicles() => _db.masters('vehicles');

  Future<List<VehicleModel>> vehiclesModels({String? query}) async {
    final rows = await _db.masters('vehicles');
    final list = rows
        .map((row) => VehicleModel.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    return list.where((vehicle) => query == null || query.isEmpty || vehicle.plateNumber.toUpperCase().contains(query.toUpperCase()) || (vehicle.driverName?.toUpperCase().contains(query.toUpperCase()) ?? false)).toList();
  }

  Future<VehicleModel?> vehicleById(String id) async {
    final rows = await _db.masters('vehicles');
    for (final row in rows) {
      if (row['id'] == id) return VehicleModel.fromJson(Map<String, dynamic>.from(row));
    }
    return null;
  }

  Future<List<PaymentRelationOption>> paymentRelationOptions() async {
    final rows = await _db.masters('payment_relations');
    return rows.map((row) => PaymentRelationOption.fromJson(Map<String, dynamic>.from(row))).toList();
  }
}

Map<String, dynamic> _bonPayload(BonModel bon, {String? imageUrl}) => {
      'id': bon.id,
      ...bon.toJson(),
      'image_url': imageUrl ?? bon.imageUrl,
      'bon_deductions': bon.deductions.map((item) => item.toJson()).toList(),
      'created_at': bon.createdAt.toUtc().toIso8601String(),
      'updated_at': bon.updatedAt.toUtc().toIso8601String(),
      'sync_version': null,
    };

Map<String, dynamic> _notaPayload(NotaModel nota, List<String> bonIds) => {
      'id': nota.id,
      ...nota.toJson(),
      'bon_ids': bonIds,
      'created_at': nota.createdAt.toUtc().toIso8601String(),
      'updated_at': nota.updatedAt.toUtc().toIso8601String(),
      'sync_version': null,
    };