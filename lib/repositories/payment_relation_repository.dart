import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/payment_relation_model.dart';

class PaymentRelationRepository {
  final SupabaseClient _client;

  PaymentRelationRepository(this._client);

  Future<List<PaymentRelationModel>> getPaymentRelations({String? query}) async {
    var request = _client
        .from('payment_relations')
        .select('*, payment_relation_accounts(*), payment_relation_vehicles(*, vehicles(*))');

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      request = request.or(
        'name.ilike.%$q%,address.ilike.%$q%,contact.ilike.%$q%',
      );
    }

    final response = await request.order('name', ascending: true);
    return (response as List)
        .map((e) => PaymentRelationModel.fromJson(e))
        .toList();
  }

  Future<List<VehicleOption>> getVehicles() async {
    final response = await _client
        .from('vehicles')
        .select('id, plate_number, driver_name')
        .order('plate_number', ascending: true);
    return (response as List).map((e) => VehicleOption.fromJson(e)).toList();
  }

  Future<void> createPaymentRelation(PaymentRelationModel paymentRelation) async {
    await _client.from('payment_relations').insert(paymentRelation.toJson());
    await _replaceChildren(paymentRelation);
  }

  Future<void> updatePaymentRelation(PaymentRelationModel paymentRelation) async {
    final data = paymentRelation.toJson()
      ..remove('id')
      ..remove('created_at');
    await _client
        .from('payment_relations')
        .update(data)
        .eq('id', paymentRelation.id);
    await _replaceChildren(paymentRelation);
  }

  Future<void> deletePaymentRelation(String id) async {
    await _client
        .from('payment_relation_accounts')
        .delete()
        .eq('payment_relation_id', id);
    await _client
        .from('payment_relation_vehicles')
        .delete()
        .eq('payment_relation_id', id);
    await _client.from('payment_relations').delete().eq('id', id);
  }

  Future<void> _replaceChildren(PaymentRelationModel paymentRelation) async {
    await _client
        .from('payment_relation_accounts')
        .delete()
        .eq('payment_relation_id', paymentRelation.id);
    await _client
        .from('payment_relation_vehicles')
        .delete()
        .eq('payment_relation_id', paymentRelation.id);

    final accounts = paymentRelation.accounts
        .where(
          (item) =>
              item.bankName.isNotEmpty ||
              item.accountNumber.isNotEmpty ||
              item.accountName.isNotEmpty,
        )
        .map((item) => item.toJson()..remove('id'))
        .toList();
    if (accounts.isNotEmpty) {
      await _client.from('payment_relation_accounts').insert(accounts);
    }

    final vehicleRows = paymentRelation.vehicles
        .where((item) => item.vehicleId.isNotEmpty)
        .map((item) => item.toJson()..remove('id'))
        .toList();
    if (vehicleRows.isNotEmpty) {
      await _client.from('payment_relation_vehicles').insert(vehicleRows);
    }
  }
}
