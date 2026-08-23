import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/nota_model.dart';
import '../../models/bon_model.dart';
import '../../core/enums.dart';

class NotaRepository {
  final SupabaseClient _client;

  NotaRepository(this._client);

  Future<List<NotaModel>> getNotas({
    DateTime? startDate,
    DateTime? endDate,
    String? driverQuery,
    String? factoryId,
  }) async {
    var query = _client.from('notas').select('''
          *,
          relation_agents(*, relation_agent_accounts(*)),
          nota_items!left(count)
        ''');

    if (startDate != null) {
      query = query.gte(
        'invoice_date',
        startDate.toIso8601String().split('T')[0],
      );
    }
    if (endDate != null) {
      final nextDay = DateTime.utc(endDate.year, endDate.month, endDate.day + 1);
      query = query.lt('invoice_date', nextDay.toIso8601String().split('T')[0]);
    }

    if (factoryId != null && factoryId.isNotEmpty) {
      final bonIdsWithFactory = await _client
          .from('bons')
          .select('id')
          .eq('factory_id', factoryId);
      final ids = (bonIdsWithFactory as List)
          .map((b) => b['id'] as String)
          .toList();
      if (ids.isNotEmpty) {
        final itemsResponse = await _client
            .from('nota_items')
            .select('invoice_id')
            .inFilter('bon_id', ids);
        final notaIds = (itemsResponse as List)
            .map((i) => i['invoice_id'] as String)
            .toList();
        if (notaIds.isNotEmpty) {
          query = query.inFilter('id', notaIds);
        } else {
          return [];
        }
      } else {
        return [];
      }
    }

    if (driverQuery != null && driverQuery.isNotEmpty) {
      // Need to find invoices that have at least one bon matching the driver
      final bonIdsWithDriver = await _client
          .from('bons')
          .select('id')
          .ilike('driver_name', '%$driverQuery%');

      final ids = (bonIdsWithDriver as List)
          .map((b) => b['id'] as String)
          .toList();

      if (ids.isNotEmpty) {
        // Find nota_ids associated with these bons
        final itemsResponse = await _client
            .from('nota_items')
            .select('invoice_id')
            .inFilter('bon_id', ids);

        final notaIds = (itemsResponse as List)
            .map((i) => i['invoice_id'] as String)
            .toList();
        if (notaIds.isNotEmpty) {
          query = query.inFilter('id', notaIds);
        } else {
          return []; // No invoices found for this driver
        }
      } else {
        return [];
      }
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).map((json) => NotaModel.fromJson(json)).toList();
  }

  Future<NotaModel> createNota(NotaModel nota, List<String> bonIds) async {
    return _insertNota(nota.toJson(), bonIds);
  }

  Future<NotaModel> _insertNota(
    Map<String, dynamic> data,
    List<String> bonIds,
  ) async {
    // 1. Create Invoice (Nota)
    final response = await _client
        .from('notas')
        .insert(data)
        .select()
        .single();

    final newNota = NotaModel.fromJson(response);

    // 2. Create Items (Nota Items)
    final items = bonIds
        .map((id) => {'invoice_id': newNota.id, 'bon_id': id})
        .toList();

    await _client.from('nota_items').insert(items);

    // 3. Update Bon Status
    await _client
        .from('bons')
        .update({'status': PaymentStatus.tertagih.value})
        .inFilter('id', bonIds);

    return newNota;
  }

  Future<void> updateNota(
    NotaModel nota,
    List<String> currentBonIds,
    List<String> newBonIds,
  ) async {
    // 1. Update Invoice Basic Data
    await _client.from('notas').update(nota.toJson()).eq('id', nota.id);

    // 2. Diff Bon IDs
    final toRemove = currentBonIds
        .where((id) => !newBonIds.contains(id))
        .toList();
    final toAdd = newBonIds.where((id) => !currentBonIds.contains(id)).toList();

    // 3. Handle Additions
    if (toAdd.isNotEmpty) {
      final items = toAdd
          .map((id) => {'invoice_id': nota.id, 'bon_id': id})
          .toList();
      await _client.from('nota_items').insert(items);
      await _client
          .from('bons')
          .update({'status': PaymentStatus.tertagih.value})
          .inFilter('id', toAdd);
    }

    // 4. Handle Removals
    if (toRemove.isNotEmpty) {
      await _client
          .from('nota_items')
          .delete()
          .eq('invoice_id', nota.id)
          .inFilter('bon_id', toRemove);
      await _client
          .from('bons')
          .update({'status': PaymentStatus.belumDibayar.value})
          .inFilter('id', toRemove);
    }
  }

  Future<void> deleteNota(String id) async {
    // 1. Check for payments before deleting
    final payments = await _client
        .from('payments')
        .select('id')
        .eq('invoice_id', id)
        .limit(1);

    if (payments.isNotEmpty) {
      throw Exception('Nota sudah memiliki pembayaran, tidak dapat dihapus.');
    }

    // 2. Get associated bons to revert their status
    final items = await _client
        .from('nota_items')
        .select('bon_id')
        .eq('invoice_id', id);
    final bonIds = (items as List).map((i) => i['bon_id'] as String).toList();

    if (bonIds.isNotEmpty) {
      await _client
          .from('bons')
          .update({'status': PaymentStatus.belumDibayar.value})
          .inFilter('id', bonIds);
    }

    // 3. Delete nota_items then nota
    await _client.from('nota_items').delete().eq('invoice_id', id);
    await _client.from('notas').delete().eq('id', id);
  }

  Future<String?> getNotaIdByBonId(String bonId) async {
    final response = await _client
        .from('nota_items')
        .select('invoice_id')
        .eq('bon_id', bonId)
        .limit(1);
    if ((response as List).isEmpty) return null;
    final id = response[0]['invoice_id'] as String?;
    return (id == null || id.isEmpty) ? null : id;
  }

  Future<NotaModel?> getNotaById(String id) async {
    final response = await _client
        .from('notas')
        .select(
          '*, relation_agents(*, relation_agent_accounts(*)), nota_items!left(count)',
        )
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return NotaModel.fromJson(response);
  }

  Future<List<BonModel>> getNotaBons(String notaId) async {
    final response = await _client
        .from('nota_items')
        .select(
          'bons(*, bon_deductions(*), factories(name), relation_agents(name))',
        )
        .eq('invoice_id', notaId);

    return (response as List)
        .map((json) => BonModel.fromJson(json['bons']))
        .toList();
  }

  Future<void> updateNotaTotal(String notaId, double totalAmount) async {
    await _client.from('notas').update({'total_amount': totalAmount.toInt()}).eq('id', notaId);
  }

  /// Gabung beberapa bon menjadi satu nota.
  /// [relationAgentId] wajib dikirim jika relasi antar bon berbeda.
  Future<NotaModel> mergeBonsIntoNota(
    List<String> bonIds, {
    String? relationAgentId,
  }) async {
    final ids = bonIds.toSet().toList();
    if (ids.length < 2) {
      throw Exception('Pilih minimal dua bon untuk digabung.');
    }

    final selected = await _client
        .from('bons')
        .select(
          'id,status,total,relation_agent_id,relation_name,driver_name,plate_number',
        )
        .inFilter('id', ids);
    if ((selected as List).length != ids.length) {
      throw Exception('Ada bon yang tidak ditemukan.');
    }
    if (selected.any(
      (b) => b['status'] == PaymentStatus.lunas.value,
    )) {
      throw Exception('Bon LUNAS tidak dapat digabung.');
    }

    // Cek pembayaran pada nota penampung bon terpilih
    final notaItems = await _client
        .from('nota_items')
        .select('invoice_id')
        .inFilter('bon_id', ids);
    final notaIds = ((notaItems as List).map((i) => i['invoice_id'] as String))
        .toSet()
        .toList();
    if (notaIds.isNotEmpty) {
      final payments = await _client
          .from('payments')
          .select('invoice_id')
          .inFilter('invoice_id', notaIds)
          .limit(1);
      if ((payments as List).isNotEmpty) {
        throw Exception(
          'Salah satu nota sudah memiliki pembayaran, tidak dapat digabung.',
        );
      }
    }

    // Hapus nota penuh atau keluarkan bon terpilih dari nota parsial
    final selectedSet = ids.toSet();
    for (final notaId in notaIds) {
      final notaBons = await getNotaBons(notaId);
      final notaBonIds = notaBons.map((bon) => bon.id).toList();
      final allInSelection =
          notaBonIds.isNotEmpty && notaBonIds.every(selectedSet.contains);
      if (allInSelection) {
        await deleteNota(notaId);
      } else {
        final toRemove = notaBonIds.where(selectedSet.contains).toList();
        if (toRemove.isNotEmpty) {
          await _client
              .from('nota_items')
              .delete()
              .eq('invoice_id', notaId)
              .inFilter('bon_id', toRemove);
          await _client
              .from('bons')
              .update({'status': PaymentStatus.belumDibayar.value})
              .inFilter('id', toRemove);
          final remainingTotal = notaBons
              .where((bon) => !selectedSet.contains(bon.id))
              .fold<double>(
                0,
                (sum, bon) => sum + bon.total,
              );
          await updateNotaTotal(notaId, remainingTotal);
        }
      }
    }

    // Tentukan relasi
    final relIds = selected
        .map((b) => b['relation_agent_id'] as String?)
        .where((id) => id != null && id.isNotEmpty)
        .toSet()
        .toList();
    final relNames = selected
        .map((b) => b['relation_name'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .toSet()
        .toList();

    Map<String, dynamic> body;
    if (relationAgentId != null && relationAgentId.isNotEmpty) {
      body = {'relation_agent_id': relationAgentId};
    } else if (relIds.length == 1) {
      body = {'relation_agent_id': relIds.first};
    } else if (relNames.length == 1) {
      body = {'recipient_name': relNames.first};
    } else {
      throw Exception('Relasi antar bon berbeda. Pilih relasi untuk nota gabungan.');
    }

    final totalAmount = selected.fold<double>(
      0,
      (sum, bon) => sum + ((bon['total'] as num?)?.toDouble() ?? 0),
    );

    final insertData = <String, dynamic>{
      ...body,
      'invoice_number': 'NOTA-${DateTime.now().millisecondsSinceEpoch}',
      'invoice_date': DateTime.now().toIso8601String(),
      'total_amount': totalAmount.toInt(),
      'status': PaymentStatus.tertagih.value,
    };

    return _insertNota(insertData, ids);
  }
}
