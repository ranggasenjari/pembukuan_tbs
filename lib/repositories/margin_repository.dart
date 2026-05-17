import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/margin_model.dart';
import '../models/payment_model.dart';

class MarginRepository {
  final SupabaseClient _client;

  MarginRepository(this._client);

  Future<List<MarginModel>> getMargins({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _client.from('margins').select();

    if (startDate != null) {
      query = query.gte(
        'transaction_date',
        startDate.toIso8601String().split('T')[0],
      );
    }
    if (endDate != null) {
      final nextDay = endDate.add(const Duration(days: 1));
      query = query.lt(
        'transaction_date',
        nextDay.toIso8601String().split('T')[0],
      );
    }

    final response = await query.order('transaction_date', ascending: false);
    return (response as List).map((e) => MarginModel.fromJson(e)).toList();
  }

  Future<void> createMargin({
    required DateTime transactionDate,
    required int offtakerAmount,
    required List<PaymentModel> selectedPayments,
  }) async {
    final int realAmount = selectedPayments.fold(
      0,
      (sum, item) => sum + item.amountPaid,
    );
    final int marginAmount = offtakerAmount - realAmount;

    // 1. Create Margin Record
    final marginResponse = await _client
        .from('margins')
        .insert({
          'transaction_date': transactionDate.toIso8601String(),
          'offtaker_amount': offtakerAmount,
          'real_amount': realAmount,
          'margin_amount': marginAmount,
        })
        .select()
        .single();

    final String marginId = marginResponse['id'];

    // 2. Update Payments with Margin ID
    final paymentIds = selectedPayments.map((e) => e.id).toList();
    if (paymentIds.isNotEmpty) {
      await _client
          .from('payments')
          .update({'margin_id': marginId})
          .filter('id', 'in', paymentIds);
    }
  }

  Future<void> updateMargin({
    required MarginModel margin,
    required List<PaymentModel> selectedPayments,
  }) async {
    final int realAmount = selectedPayments.fold(
      0,
      (sum, item) => sum + item.amountPaid,
    );
    final int marginAmount = margin.offtakerAmount - realAmount;

    // 1. Update Margin Record
    await _client
        .from('margins')
        .update({
          'transaction_date': margin.transactionDate.toIso8601String(),
          'offtaker_amount': margin.offtakerAmount,
          'real_amount': realAmount,
          'margin_amount': marginAmount,
        })
        .eq('id', margin.id);

    // 2. Refresh Payments (Unlink all old, then link new)
    // a. Unlink all currently assigned data
    await _client
        .from('payments')
        .update({'margin_id': null})
        .eq('margin_id', margin.id);

    // b. Link selected payments
    final paymentIds = selectedPayments.map((e) => e.id).toList();
    if (paymentIds.isNotEmpty) {
      await _client
          .from('payments')
          .update({'margin_id': margin.id})
          .filter('id', 'in', paymentIds);
    }
  }

  Future<void> deleteMargin(String id) async {
    // 1. Unlink Payments
    await _client
        .from('payments')
        .update({'margin_id': null})
        .eq('margin_id', id);

    // 2. Delete Margin
    await _client.from('margins').delete().eq('id', id);
  }
}
