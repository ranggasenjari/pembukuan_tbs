import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/payment_model.dart';

class PaymentRepository {
  final SupabaseClient _client;

  PaymentRepository(this._client);

  Future<List<PaymentModel>> getPayments(String notaId) async {
    final response = await _client
        .from('payments')
        .select()
        .eq('invoice_id', notaId)
        .order('created_at', ascending: false);

    return (response as List).map((e) => PaymentModel.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getAllPayments({
    DateTime? startDate,
    DateTime? endDate,
    String? driverQuery,
    String? factoryId,
  }) async {
    var selectQuery = '*, notas(id, invoice_number, total_amount)';

    if (driverQuery != null && driverQuery.isNotEmpty) {
      selectQuery =
          '*, notas!inner(id, invoice_number, total_amount, nota_items!inner(bons!inner(driver_name)))';
    }

    var query = _client.from('payments').select(selectQuery);

    if (startDate != null) {
      query = query.gte(
        'payment_date',
        startDate.toIso8601String().split('T')[0],
      );
    }
    if (endDate != null) {
      final nextDay = DateTime.utc(endDate.year, endDate.month, endDate.day + 1);
      query = query.lt('payment_date', nextDay.toIso8601String().split('T')[0]);
    }
    if (driverQuery != null && driverQuery.isNotEmpty) {
      query = query.ilike(
        'notas.nota_items.bons.driver_name',
        '%$driverQuery%',
      );
    }

    var response = await query.order('payment_date', ascending: false);

    var results = List<Map<String, dynamic>>.from(response);

    // Apply factory filter client-side if needed
    if (factoryId != null && factoryId.isNotEmpty) {
      final filteredIds = <String>{};
      for (final payment in results) {
        final nota = payment['notas'];
        if (nota is Map) {
          final notaId = nota['id'] as String?;
          if (notaId != null && await _paymentHasFactoryBon(notaId, factoryId)) {
            filteredIds.add(payment['id'] as String);
          }
        }
      }
      results = results
          .where((p) => filteredIds.contains(p['id'] as String))
          .toList();
    }

    return results;
  }

  Future<bool> _paymentHasFactoryBon(String notaId, String factoryId) async {
    final items = await _client
        .from('nota_items')
        .select('bons!inner(factory_id)')
        .eq('invoice_id', notaId)
        .eq('bons.factory_id', factoryId)
        .limit(1);
    return (items as List).isNotEmpty;
  }

  Future<PaymentModel> createPayment(
    PaymentModel payment,
    Uint8List? proofBytes,
    String? fileName,
  ) async {
    String? proofUrl;
    if (proofBytes != null && fileName != null) {
      final path =
          'payments/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _client.storage.from('payments').uploadBinary(path, proofBytes);
      proofUrl = _client.storage.from('payments').getPublicUrl(path);
    }

    final paymentData = payment.toJson();
    if (proofUrl != null) {
      paymentData['proof_url'] = proofUrl;
    }
    paymentData.remove('id');

    final response = await _client
        .from('payments')
        .insert(paymentData)
        .select()
        .single();

    // 1. Update Nota Status
    await _client
        .from('notas')
        .update({'status': 'LUNAS'})
        .eq('id', payment.notaId);

    // 2. Find associated Bons and Update their Status to LUNAS
    final notaItemsResponse = await _client
        .from('nota_items')
        .select('bon_id')
        .eq('invoice_id', payment.notaId);
    final bonIds = (notaItemsResponse as List)
        .map((e) => e['bon_id'] as String)
        .toList();

    if (bonIds.isNotEmpty) {
      await _client
          .from('bons')
          .update({'status': 'LUNAS'})
          .inFilter('id', bonIds);
    }

    return PaymentModel.fromJson(response);
  }

  /// Fetches payments that have not yet been assigned to a margin (margin_id is null)
  /// Optionally includes payments assigned to a specific margin (for editing)
  Future<List<Map<String, dynamic>>> getUnassignedPayments({
    String? includeMarginId,
  }) async {
    var query = _client
        .from('payments')
        .select(
          '*, notas(invoice_number, recipient_name, nota_items(bons(netto_2, price)))',
        );

    if (includeMarginId != null) {
      query = query.or('margin_id.is.null,margin_id.eq.$includeMarginId');
    } else {
      query = query.filter('margin_id', 'is', 'null');
    }

    final response = await query.order('payment_date', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> updatePayment(PaymentModel payment) async {
    // 1. Check if assigned to Margin
    if (payment.marginId != null) {
      throw Exception(
        'Pembayaran sudah tercatat dalam margin, tidak dapat diedit.',
      );
    }

    // 2. Update
    final data = payment.toJson();
    data.remove('id');
    await _client.from('payments').update(data).eq('id', payment.id);
  }

  Future<void> deletePayment(String id) async {
    // 1. Get Payment details to check logic
    final payment = await _client
        .from('payments')
        .select()
        .eq('id', id)
        .single();
    if (payment['margin_id'] != null) {
      throw Exception(
        'Pembayaran sudah tercatat dalam margin, tidak dapat dihapus.',
      );
    }

    final notaId = payment['invoice_id'];

    // 2. Delete Payment
    await _client.from('payments').delete().eq('id', id);

    // 3. Revert Nota and related Bons to waiting payment state
    if (notaId != null) {
      await _client
          .from('notas')
          .update({'status': 'TERTAGIH'})
          .eq('id', notaId);

      final notaItemsResponse = await _client
          .from('nota_items')
          .select('bon_id')
          .eq('invoice_id', notaId);
      final bonIds = (notaItemsResponse as List)
          .map((e) => e['bon_id'] as String)
          .toList();

      if (bonIds.isNotEmpty) {
        await _client
            .from('bons')
            .update({'status': 'TERTAGIH'})
            .inFilter('id', bonIds);
      }
    }
  }

  Future<int> getTotalPayments() async {
    final response = await _client.from('payments').select('amount_paid');
    final List<dynamic> data = response as List<dynamic>;
    if (data.isEmpty) return 0;
    return data.fold<int>(0, (sum, item) => sum + (item['amount_paid'] as int));
  }
}
