import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vehicle_model.dart';

class VehicleRepository {
  final SupabaseClient _client;

  VehicleRepository(this._client);

  Future<List<VehicleModel>> getVehicles({String? query}) async {
    var request = _client
        .from('vehicles')
        .select(
          '*, payment_relation_vehicles(payment_relation_id, payment_relations(name))',
        );
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      request = request.or(
        'plate_number.ilike.%$q%,driver_name.ilike.%$q%',
      );
    }
    final response = await request.order('plate_number', ascending: true);
    return (response as List)
        .map((e) => VehicleModel.fromJson(e))
        .toList();
  }

  Future<VehicleModel> getVehicle(String id) async {
    final response = await _client
        .from('vehicles')
        .select(
          '*, payment_relation_vehicles(payment_relation_id, payment_relations(name))',
        )
        .eq('id', id)
        .single();
    return VehicleModel.fromJson(response);
  }

  Future<List<PaymentRelationOption>> getPaymentRelationOptions() async {
    final response = await _client
        .from('payment_relations')
        .select('id, name')
        .order('name', ascending: true);
    return (response as List).map((e) => PaymentRelationOption.fromJson(e)).toList();
  }

  Future<void> createVehicle(VehicleModel vehicle) async {
    final data = vehicle.toJson()..remove('is_super');
    data['is_super'] = vehicle.isSuper;
    await _client.from('vehicles').insert(data);
    if (vehicle.paymentRelationId != null) {
      await _bindRelation(vehicle.id, vehicle.paymentRelationId!);
    }
  }

  Future<void> updateVehicle(VehicleModel vehicle) async {
    final data = vehicle.toJson();
    await _client
        .from('vehicles')
        .update(data)
        .eq('id', vehicle.id);
    await updateVehicleRelation(vehicle.id, vehicle.paymentRelationId);
  }

  Future<void> updateVehicleRelation(
    String vehicleId,
    String? relationId,
  ) async {
    await _client
        .from('payment_relation_vehicles')
        .delete()
        .eq('vehicle_id', vehicleId);
    final id = relationId?.trim();
    if (id != null && id.isNotEmpty) {
      await _client.from('payment_relation_vehicles').insert({
        'payment_relation_id': id,
        'vehicle_id': vehicleId,
      });
    }
  }

  Future<void> _bindRelation(String vehicleId, String relationId) async {
    await _client.from('payment_relation_vehicles').insert({
      'payment_relation_id': relationId,
      'vehicle_id': vehicleId,
    });
  }

  Future<void> deleteVehicle(String id) async {
    await _client
        .from('payment_relation_vehicles')
        .delete()
        .eq('vehicle_id', id);
    await _client.from('vehicles').delete().eq('id', id);
  }
}