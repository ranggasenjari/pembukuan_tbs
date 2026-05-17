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
  }) async {
    var query = _client.from('notas').select('''
          *,
          nota_items!left(count)
        ''');

    if (startDate != null) {
      query = query.gte(
        'invoice_date',
        startDate.toIso8601String().split('T')[0],
      );
    }
    if (endDate != null) {
      // LT with next day (normalized to date only)
      final nextDay = endDate.add(const Duration(days: 1));
      query = query.lt('invoice_date', nextDay.toIso8601String().split('T')[0]);
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

    final response = await query.order('invoice_date', ascending: false);
    return (response as List).map((json) => NotaModel.fromJson(json)).toList();
  }

  Future<NotaModel> createNota(NotaModel nota, List<String> bonIds) async {
    // 1. Create Invoice (Nota)
    final response = await _client
        .from('notas')
        .insert(nota.toJson())
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

  Future<List<BonModel>> getNotaBons(String notaId) async {
    final response = await _client
        .from('nota_items')
        .select('bons(*, bon_deductions(*))')
        .eq('invoice_id', notaId);

    return (response as List)
        .map((json) => BonModel.fromJson(json['bons']))
        .toList();
  }
}
