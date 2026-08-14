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
import 'offline_database.dart';

class OfflineBonRepository {
  OfflineBonRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final OfflineDatabase _db;
  final Uuid _uuid;

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

  Future<BonModel> createBon(BonModel bon, Uint8List? imageBytes, String? fileName,
      {String? existingImageUrl}) async {
    final imagePath = imageBytes == null ? null : await _copyAttachment(bon.id, imageBytes, fileName);
    final payload = _bonPayload(bon, imageUrl: existingImageUrl);
    await _db.saveBon(payload: payload, syncState: 'pending', imagePath: imagePath);
    await _enqueueBon(payload, imagePath: imagePath);
    return BonModel.fromJson(payload);
  }

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

  Future<void> deleteBon(String id) async {
    final row = await _db.bon(id);
    if (row == null) return;
    final payload = row.payload;
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

class OfflineNotaRepository {
  OfflineNotaRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();
  final OfflineDatabase _db;
  final Uuid _uuid;

  Future<List<NotaModel>> getNotas({DateTime? startDate, DateTime? endDate, String? driverQuery, String? factoryId}) async {
    return (await _db.notas()).map((row) => NotaModel.fromJson(row.payload)).toList();
  }

  Future<NotaModel> createNota(NotaModel nota, List<String> bonIds) async {
    final payload = _notaPayload(nota, bonIds);
    await _db.saveNota(payload: payload, syncState: 'pending');
    await _assignBons(nota.id, bonIds, PaymentStatus.tertagih);
    await _enqueue(payload);
    return NotaModel.fromJson(payload);
  }

  Future<void> updateNota(NotaModel nota, List<String> currentBonIds, List<String> newBonIds) async {
    final row = await _db.nota(nota.id);
    final payload = _notaPayload(nota, newBonIds);
    await _assignBons(nota.id, currentBonIds.where((id) => !newBonIds.contains(id)).toList(), PaymentStatus.belumDibayar, clearNota: true);
    await _assignBons(nota.id, newBonIds, PaymentStatus.tertagih);
    await _db.saveNota(payload: payload, syncState: 'pending', remoteVersion: row?.remoteVersion);
    await _enqueue(payload, baseVersion: row?.remoteVersion);
  }

  Future<List<BonModel>> getNotaBons(String notaId) async =>
      (await _db.bons(notaId: notaId)).map((row) => BonModel.fromJson(row.payload)).toList();

  Future<String?> getNotaIdByBonId(String bonId) async => (await _db.bon(bonId))?.notaId;

  Future<void> deleteNota(String id) async {
    final row = await _db.nota(id);
    if (row == null) return;
    final ids = (row.payload['bon_ids'] as List? ?? const []).map((e) => e.toString()).toList();
    await _assignBons(id, ids, PaymentStatus.belumDibayar, clearNota: true);
    await _db.deleteNota(id);
    await _db.deleteOperationWhereEntity('nota', id);
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

  Future<List<RelationAgentModel>> relations({String? query}) async {
    final rows = await _db.masters('relation_agents');
    final accounts = await _db.masters('relation_agent_accounts');
    return rows.map((row) => RelationAgentModel.fromJson({
          ...row,
          'relation_agent_accounts': accounts.where((x) => x['relation_agent_id'] == row['id']).toList(),
        })).where((relation) => query == null || query.isEmpty || relation.name.toUpperCase().contains(query.toUpperCase())).toList();
  }

  Future<List<Map<String, dynamic>>> vehicles() => _db.masters('vehicles');
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
