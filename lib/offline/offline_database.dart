import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// SQLCipher-backed local store for the offline Android flavor.
///
/// The tables intentionally keep domain payloads as JSON. This makes the local
/// queue forward-compatible with the Supabase schema while the application is
/// rolled out independently from the cloud migration.
class OfflineDatabase {
  OfflineDatabase._(this._database, this.userId);

  final Database _database;
  final String userId;

  static Future<OfflineDatabase> open({
    required String userId,
    required String encryptionKey,
  }) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'offline', userId));
    await directory.create(recursive: true);
    final db = await openDatabase(
      p.join(directory.path, 'operasional.db'),
      password: encryptionKey,
      version: 1,
      onCreate: (database, _) async {
        await database.execute('''
          CREATE TABLE masters (
            type TEXT NOT NULL,
            id TEXT NOT NULL,
            payload TEXT NOT NULL,
            updated_at TEXT,
            PRIMARY KEY(type, id)
          )
        ''');
        await database.execute('''
          CREATE TABLE bons (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            sync_state TEXT NOT NULL,
            remote_version INTEGER,
            image_path TEXT,
            nota_id TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE notas (
            id TEXT PRIMARY KEY,
            payload TEXT NOT NULL,
            sync_state TEXT NOT NULL,
            remote_version INTEGER,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE outbox (
            operation_id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            payload TEXT NOT NULL,
            attachment_path TEXT,
            state TEXT NOT NULL,
            retries INTEGER NOT NULL DEFAULT 0,
            last_error TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
    );
    return OfflineDatabase._(db, userId);
  }

  Future<void> close() => _database.close();

  Future<void> replaceMasters(
    String type,
    List<Map<String, dynamic>> rows,
  ) async {
    await _database.transaction((transaction) async {
      await transaction.delete('masters', where: 'type = ?', whereArgs: [type]);
      final batch = transaction.batch();
      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null || id.isEmpty) continue;
        batch.insert('masters', {
          'type': type,
          'id': id,
          'payload': jsonEncode(row),
          'updated_at': row['updated_at']?.toString(),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<List<Map<String, dynamic>>> masters(String type) async {
    final rows = await _database.query(
      'masters',
      where: 'type = ?',
      whereArgs: [type],
      orderBy: 'payload ASC',
    );
    return rows
        .map((row) => Map<String, dynamic>.from(jsonDecode(row['payload']! as String)))
        .toList();
  }

  Future<void> setMetadata(String key, String value) => _database.insert(
        'metadata',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<String?> metadata(String key) async {
    final rows = await _database.query(
      'metadata',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> saveBon({
    required Map<String, dynamic> payload,
    required String syncState,
    String? imagePath,
    String? notaId,
    int? remoteVersion,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.insert(
      'bons',
      {
        'id': payload['id'],
        'payload': jsonEncode(payload),
        'sync_state': syncState,
        'remote_version': remoteVersion,
        'image_path': imagePath,
        'nota_id': notaId,
        'created_at': payload['created_at'] ?? now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OfflineBonRow>> bons({String? notaId}) async {
    final rows = await _database.query(
      'bons',
      where: notaId == null ? null : 'nota_id = ?',
      whereArgs: notaId == null ? null : [notaId],
      orderBy: 'created_at DESC',
    );
    return rows.map(OfflineBonRow.fromRow).toList();
  }

  Future<OfflineBonRow?> bon(String id) async {
    final rows = await _database.query('bons', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : OfflineBonRow.fromRow(rows.first);
  }

  Future<void> deleteBon(String id) =>
      _database.delete('bons', where: 'id = ?', whereArgs: [id]);

  Future<void> saveNota({
    required Map<String, dynamic> payload,
    required String syncState,
    int? remoteVersion,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _database.insert(
      'notas',
      {
        'id': payload['id'],
        'payload': jsonEncode(payload),
        'sync_state': syncState,
        'remote_version': remoteVersion,
        'created_at': payload['created_at'] ?? now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OfflineNotaRow>> notas() async {
    final rows = await _database.query('notas', orderBy: 'created_at DESC');
    return rows.map(OfflineNotaRow.fromRow).toList();
  }

  Future<OfflineNotaRow?> nota(String id) async {
    final rows = await _database.query('notas', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : OfflineNotaRow.fromRow(rows.first);
  }

  Future<void> deleteNota(String id) =>
      _database.delete('notas', where: 'id = ?', whereArgs: [id]);

  Future<void> enqueue(OfflineOperation operation) => _database.insert(
        'outbox',
        operation.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

  Future<List<OfflineOperation>> pendingOperations() async {
    final rows = await _database.query(
      'outbox',
      where: "state IN ('pending', 'failed')",
      orderBy: 'created_at ASC',
    );
    return rows.map(OfflineOperation.fromRow).toList();
  }

  Future<int> pendingCount() async {
    final result = await _database.rawQuery(
      "SELECT COUNT(*) AS value FROM outbox WHERE state IN ('pending', 'failed')",
    );
    return (result.first['value'] as num?)?.toInt() ?? 0;
  }

  Future<void> updateOperation(
    String id, {
    required String state,
    String? error,
    bool incrementRetries = false,
  }) async {
    await _database.rawUpdate(
      'UPDATE outbox SET state = ?, last_error = ?, retries = retries + ?, updated_at = ? WHERE operation_id = ?',
      [
        state,
        error,
        incrementRetries ? 1 : 0,
        DateTime.now().toUtc().toIso8601String(),
        id,
      ],
    );
  }

  Future<void> deleteOperation(String id) =>
      _database.delete('outbox', where: 'operation_id = ?', whereArgs: [id]);

  Future<void> deleteOperationWhereEntity(String entityType, String entityId) =>
      _database.delete(
        'outbox',
        where: 'entity_type = ? AND entity_id = ?',
        whereArgs: [entityType, entityId],
      );

  Future<void> purgeNotaBundle(String notaId) async {
    final linked = await bons(notaId: notaId);
    await _database.transaction((transaction) async {
      await transaction.delete('notas', where: 'id = ?', whereArgs: [notaId]);
      await transaction.delete('bons', where: 'nota_id = ?', whereArgs: [notaId]);
    });
    for (final bon in linked) {
      final path = bon.imagePath;
      if (path != null && path.isNotEmpty) {
        if (await File(path).exists()) await File(path).delete();
      }
    }
  }
}

class OfflineBonRow {
  OfflineBonRow({
    required this.payload,
    required this.syncState,
    this.imagePath,
    this.notaId,
    this.remoteVersion,
  });
  final Map<String, dynamic> payload;
  final String syncState;
  final String? imagePath;
  final String? notaId;
  final int? remoteVersion;
  factory OfflineBonRow.fromRow(Map<String, Object?> row) => OfflineBonRow(
        payload: Map<String, dynamic>.from(jsonDecode(row['payload']! as String)),
        syncState: row['sync_state']! as String,
        imagePath: row['image_path'] as String?,
        notaId: row['nota_id'] as String?,
        remoteVersion: (row['remote_version'] as num?)?.toInt(),
      );
}

class OfflineNotaRow {
  OfflineNotaRow({required this.payload, required this.syncState, this.remoteVersion});
  final Map<String, dynamic> payload;
  final String syncState;
  final int? remoteVersion;
  factory OfflineNotaRow.fromRow(Map<String, Object?> row) => OfflineNotaRow(
        payload: Map<String, dynamic>.from(jsonDecode(row['payload']! as String)),
        syncState: row['sync_state']! as String,
        remoteVersion: (row['remote_version'] as num?)?.toInt(),
      );
}

class OfflineOperation {
  OfflineOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.payload,
    this.attachmentPath,
    this.state = 'pending',
    this.retries = 0,
    this.lastError,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();

  final String id;
  final String entityType;
  final String entityId;
  final Map<String, dynamic> payload;
  final String? attachmentPath;
  final String state;
  final int retries;
  final String? lastError;
  final DateTime createdAt;

  Map<String, Object?> toRow() => {
        'operation_id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'payload': jsonEncode(payload),
        'attachment_path': attachmentPath,
        'state': state,
        'retries': retries,
        'last_error': lastError,
        'created_at': createdAt.toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  factory OfflineOperation.fromRow(Map<String, Object?> row) => OfflineOperation(
        id: row['operation_id']! as String,
        entityType: row['entity_type']! as String,
        entityId: row['entity_id']! as String,
        payload: Map<String, dynamic>.from(jsonDecode(row['payload']! as String)),
        attachmentPath: row['attachment_path'] as String?,
        state: row['state']! as String,
        retries: (row['retries'] as num?)?.toInt() ?? 0,
        lastError: row['last_error'] as String?,
        createdAt: DateTime.parse(row['created_at']! as String),
      );
}
