import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'offline_database.dart';
import 'offline_session_service.dart';
import 'offline_sync_service.dart';

/// Memantau status koneksi internet dari sisi perangkat.
class ConnectivityService {
  ConnectivityService() {
    try {
      _conn.onConnectivityChanged.listen(_update);
    } catch (_) {}
    _refresh();
  }

  final _conn = Connectivity();
  final ValueNotifier<bool> online = ValueNotifier<bool>(true);

  void _update(List<ConnectivityResult> results) {
    online.value = !results.any((r) => r == ConnectivityResult.none);
  }

  Future<void> _refresh() async {
    try {
      _update(await _conn.checkConnectivity());
    } catch (_) {}
  }

  void onChange(void Function(bool online) listener) {
    online.addListener(() => listener(online.value));
  }

  void dispose() => online.dispose();
}

/// State gabungan untuk indikator status offline/sinkron pada UI shell.
class OfflineUiState {
  const OfflineUiState({
    this.online = true,
    this.pending = 0,
    this.status = OfflineSyncStatus.idle,
    this.message,
  });

  final bool online;
  final int pending;
  final OfflineSyncStatus status;
  final String? message;
}

/// Mengelola seluruh mesin offline: sesi lokal, database SQLCipher,
/// sinkronisasi antrean, dan penarikan data dari cloud ke cache lokal.
/// Dibuat sekali di `main` lalu disuntikkan ke ProviderScope.
class SyncCoordinator {
  SyncCoordinator(this._sessions, this._connectivity, this._client);

  final OfflineSessionService _sessions;
  final ConnectivityService _connectivity;
  final SupabaseClient _client;

  OfflineSession? session;
  OfflineDatabase? db;
  OfflineBootstrapService? bootstrap;
  OfflineSyncService? sync;

  final ValueNotifier<OfflineUiState> ui =
      ValueNotifier(const OfflineUiState());

  bool get hasDatabase => db != null;

  bool get online => _connectivity.online.value;

  ConnectivityService get connectivity => _connectivity;

  Future<OfflineSession?> loadSession() => _sessions.currentSession();

  /// Verifikasi PIN lalu buka database lokal (dipakai saat login offline).
  Future<bool> unlock(String pin) async {
    final current = session ?? await _sessions.currentSession();
    if (current == null) return false;
    if (!await _sessions.unlock(pin)) return false;
    await attach(current);
    return true;
  }

  bool _listening = false;

  /// Membuka database lokal untuk sesi yang sudah ada (tanpa memverifikasi PIN).
  Future<void> attach(OfflineSession s) async {
    if (db != null && session?.userId == s.userId) return;
    session = s;
    final old = db;
    if (old != null) {
      db = null;
      sync?.dispose();
      sync = null;
      bootstrap = null;
      try {
        await old.close();
      } catch (_) {}
    }
    final opened = await _sessions.openDatabase(s);
    db = opened;
    bootstrap = OfflineBootstrapService(_client, opened);
    sync = OfflineSyncService(
      client: _client,
      database: opened,
      deviceId: s.deviceId,
    );
    if (!_listening) {
      _listening = true;
      _connectivity.onChange((_) => syncNow());
    }
    // Sinkronisasi tidak memblokir pembukaan aplikasi; berjalan di background.
    unawaited(syncNow());
  }

  /// Mengaktifkan sesi offline baru (dipanggil setelah login online).
  Future<void> activate({
    required String userId,
    required String email,
    required String pin,
  }) async {
    final s = await _sessions.activate(
      userId: userId,
      email: email,
      pin: pin,
    );
    await attach(s);
  }

  Future<void> _refreshUi({String? message}) async {
    final pending = db == null ? 0 : await db!.pendingCount();
    ui.value = OfflineUiState(
      online: _connectivity.online.value,
      pending: pending,
      status: sync?.snapshots.value.status ?? OfflineSyncStatus.idle,
      message: message,
    );
  }

  Future<int> pending() async => db == null ? 0 : db!.pendingCount();

  static bool _isLocalOnly(String syncState) =>
      syncState == 'pending' ||
      syncState == 'pending_delete' ||
      syncState == 'uploading' ||
      syncState == 'syncing' ||
      syncState == 'failed';

  /// Menarik master + bon + nota dari cloud ke cache lokal.
  /// Baris lokal yang belum tersinkron tidak ditimpa.
  Future<void> pullAll() async {
    if (db == null) return;
    final d = db!;
    try {
      await bootstrap?.refreshMasters();
    } catch (_) {}

    try {
      final bonsResp = await _client
          .from('bons')
          .select('*, bon_deductions(*), factories(name), relation_agents(name)')
          .order('created_at', ascending: false);
      for (final row in bonsResp as List) {
        final map = Map<String, dynamic>.from(row);
        final id = map['id']?.toString();
        if (id == null) continue;
        final existing = await d.bon(id);
        if (existing != null && _isLocalOnly(existing.syncState)) continue;
        final payload = Map<String, dynamic>.from(map)
          ..remove('factories')
          ..remove('relation_agents');
        await d.saveBon(
          payload: payload,
          syncState: 'synced_active',
          remoteVersion: (map['sync_version'] as num?)?.toInt(),
        );
      }
    } catch (_) {}

    try {
      final notasResp = await _client
          .from('notas')
          .select('*')
          .order('created_at', ascending: false);
      var itemsResp = const <dynamic>[];
      try {
        itemsResp = await _client.from('nota_items').select('invoice_id, bon_id');
      } catch (_) {}
      final byNota = <String, List<String>>{};
      for (final it in itemsResp) {
        final invoiceId = it['invoice_id']?.toString();
        if (invoiceId == null) continue;
        byNota.putIfAbsent(invoiceId, () => <String>[]).add(it['bon_id'].toString());
      }
      for (final row in notasResp as List) {
        final map = Map<String, dynamic>.from(row);
        final id = map['id']?.toString();
        if (id == null) continue;
        final notaRow = await d.nota(id);
        if (notaRow != null && _isLocalOnly(notaRow.syncState)) continue;
        final payload = Map<String, dynamic>.from(map)
          ..['bon_ids'] = byNota[id] ?? <String>[];
        await d.saveNota(
          payload: payload,
          syncState: 'synced_active',
          remoteVersion: (map['sync_version'] as num?)?.toInt(),
        );
        for (final bonId in payload['bon_ids'] as List) {
          final existing = await d.bon(bonId.toString());
          if (existing == null || _isLocalOnly(existing.syncState)) continue;
          await d.saveBon(
            payload: existing.payload,
            syncState: existing.syncState,
            imagePath: existing.imagePath,
            notaId: id,
            remoteVersion: existing.remoteVersion,
          );
        }
      }
    } catch (_) {}
    await _refreshUi();
  }

  Future<void> syncNow() async {
    if (_connectivity.online.value == false) {
      _refreshUi();
      return;
    }
    // Dorong antrean lebih dulu agar perubahan lokal naik ke cloud,
    // baru tarik data terbaru ke cache lokal.
    if (sync != null) await sync!.syncNow();
    try {
      await pullAll();
    } catch (_) {}
    await _refreshUi();
  }

  Future<void> refreshMasters() async {
    try {
      await bootstrap?.refreshMasters();
    } catch (_) {}
  }

  void dispose() {
    _connectivity.dispose();
    sync?.dispose();
  }
}