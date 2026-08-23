import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_database.dart';

enum OfflineSyncStatus { idle, syncing, offline, failed, complete }

class OfflineSyncSnapshot {
  const OfflineSyncSnapshot({required this.status, required this.pending, this.message, this.lastAttempt});
  final OfflineSyncStatus status;
  final int pending;
  final String? message;
  final DateTime? lastAttempt;
}

class OfflineBootstrapService {
  OfflineBootstrapService(this._client, this._db);
  final SupabaseClient _client;
  final OfflineDatabase _db;

  Future<void> refreshMasters() async {
    final response = await _client.functions.invoke('offline-bootstrap');
    if (response.status != 200) throw StateError('Bootstrap gagal: ${response.status}');
    final data = Map<String, dynamic>.from(response.data as Map);
    final masters = Map<String, dynamic>.from(data['masters'] as Map? ?? const {});
    for (final entry in masters.entries) {
      final rows = (entry.value as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      await _db.replaceMasters(entry.key, rows);
    }
    if (data['version'] != null) await _db.setMetadata('master_version', data['version'].toString());
  }
}

class OfflineSyncService {
  OfflineSyncService({
    required SupabaseClient client,
    required OfflineDatabase database,
    required String deviceId,
    http.Client? httpClient,
  })  : _client = client,
        _db = database,
        _deviceId = deviceId,
        _http = httpClient ?? http.Client();

  final SupabaseClient _client;
  final OfflineDatabase _db;
  final String _deviceId;
  final http.Client _http;
  final snapshots = ValueNotifier<OfflineSyncSnapshot>(
    const OfflineSyncSnapshot(status: OfflineSyncStatus.idle, pending: 0),
  );
  bool _running = false;

  Future<void> syncNow() async {
    if (_running) return;
    _running = true;
    try {
      var operations = await _db.pendingOperations();
      snapshots.value = OfflineSyncSnapshot(
        status: OfflineSyncStatus.syncing,
        pending: operations.length,
        lastAttempt: DateTime.now(),
      );
      String? firstError;
      for (final operation in operations) {
        try {
          await _syncOperation(operation);
        } catch (error) {
          // Satu item gagal tidak boleh memblokir item lain; lanjutkan.
          firstError ??= error.toString();
        }
        operations = await _db.pendingOperations();
        snapshots.value = OfflineSyncSnapshot(
          status: OfflineSyncStatus.syncing,
          pending: operations.length,
          lastAttempt: DateTime.now(),
        );
      }
      final remaining = await _db.pendingCount();
      snapshots.value = OfflineSyncSnapshot(
        status: remaining == 0 ? OfflineSyncStatus.complete : OfflineSyncStatus.failed,
        pending: remaining,
        message: remaining > 0 ? firstError : null,
        lastAttempt: DateTime.now(),
      );
    } on SocketException catch (_) {
      snapshots.value = OfflineSyncSnapshot(
        status: OfflineSyncStatus.offline,
        pending: await _db.pendingCount(),
        message: 'Supabase belum dapat dijangkau.',
        lastAttempt: DateTime.now(),
      );
    } catch (error) {
      snapshots.value = OfflineSyncSnapshot(
        status: OfflineSyncStatus.failed,
        pending: await _db.pendingCount(),
        message: error.toString(),
        lastAttempt: DateTime.now(),
      );
    } finally {
      _running = false;
    }
  }

  Future<void> _syncOperation(OfflineOperation operation) async {
    try {
      await _db.updateOperation(operation.id, state: 'uploading');
      String? objectPath;
      if (operation.attachmentPath != null) {
        objectPath = await _uploadAttachment(operation);
      }
      await _db.updateOperation(operation.id, state: 'syncing');
      final response = await _client.functions.invoke(
        'offline-sync',
        body: {
          'device_id': _deviceId,
          'operation_id': operation.id,
          'entity_type': operation.entityType,
          'entity_id': operation.entityId,
          'payload': operation.payload,
          if (objectPath != null) 'attachment_path': objectPath,
        },
      );
      final data = Map<String, dynamic>.from(response.data as Map? ?? const {});
      if (response.status == 409 || data['status'] == 'conflict') {
        await _discardCloudConflict(operation);
        return;
      }
      if (response.status < 200 || response.status >= 300 || data['status'] == 'error') {
        throw StateError(data['message'] ?? 'Sync ditolak (${response.status}).');
      }
      await _commitSuccess(operation, data);
    } catch (error) {
      await _db.updateOperation(
        operation.id,
        state: 'failed',
        error: error.toString(),
        incrementRetries: true,
      );
      rethrow;
    }
  }

  Future<String> _uploadAttachment(OfflineOperation operation) async {
    final file = File(operation.attachmentPath!);
    if (!await file.exists()) throw StateError('Foto bon lokal tidak ditemukan.');
    final prep = await _client.functions.invoke(
      'offline-upload-url',
      body: {
        'device_id': _deviceId,
        'operation_id': operation.id,
        'file_name': file.uri.pathSegments.last,
      },
    );
    if (prep.status < 200 || prep.status >= 300) throw StateError('Tidak dapat menyiapkan upload foto.');
    final data = Map<String, dynamic>.from(prep.data as Map);
    final uploadUrl = Uri.parse(data['upload_url'] as String);
    final upload = await _http.put(uploadUrl, body: await file.readAsBytes());
    if (upload.statusCode < 200 || upload.statusCode >= 300) {
      throw StateError('Upload foto gagal (${upload.statusCode}).');
    }
    return data['object_path'] as String;
  }

  Future<void> _commitSuccess(OfflineOperation operation, Map<String, dynamic> response) async {
    if (operation.entityType == 'bon') {
      final row = await _db.bon(operation.entityId);
      if (row != null) {
        await _db.saveBon(
          payload: row.payload,
          syncState: 'synced_active',
          imagePath: row.imagePath,
          notaId: row.notaId,
          remoteVersion: (response['sync_version'] as num?)?.toInt() ?? 1,
        );
      }
    } else if (operation.entityType == 'nota') {
      await _db.purgeNotaBundle(operation.entityId);
    } else if (operation.entityType == 'sub_nota') {
      final row = await _db.subNota(operation.entityId);
      if (row != null) {
        await _db.saveSubNota(
          payload: row.payload,
          syncState: 'synced_active',
          remoteVersion: (response['sync_version'] as num?)?.toInt() ?? 1,
        );
      }
    } else if (operation.entityType == 'sub_nota_delete') {
      await _db.deleteSubNota(operation.entityId);
    } else if (operation.entityType == 'bon_delete') {
      final row = await _db.bon(operation.entityId);
      if (row?.imagePath != null) {
        final file = File(row!.imagePath!);
        if (await file.exists()) await file.delete();
      }
      await _db.deleteBon(operation.entityId);
    }
    await _db.deleteOperation(operation.id);
  }

  Future<void> _discardCloudConflict(OfflineOperation operation) async {
    if (operation.entityType == 'nota') {
      await _db.purgeNotaBundle(operation.entityId);
    } else if (operation.entityType == 'sub_nota' ||
        operation.entityType == 'sub_nota_delete') {
      await _db.deleteSubNota(operation.entityId);
    } else {
      final row = await _db.bon(operation.entityId);
      if (row?.imagePath != null) {
        final file = File(row!.imagePath!);
        if (await file.exists()) await file.delete();
      }
      await _db.deleteBon(operation.entityId);
    }
    await _db.deleteOperation(operation.id);
  }

  void dispose() {
    snapshots.dispose();
    _http.close();
  }
}
