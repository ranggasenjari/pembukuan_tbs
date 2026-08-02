import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/factory_model.dart';

class FactoryRepository {
  final SupabaseClient _client;

  FactoryRepository(this._client);

  Future<List<FactoryModel>> getFactories({String? query}) async {
    var request = _client.from('factories').select('*, factory_spsi_types(*), factory_prices(*)');
    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim();
      request = request.or('name.ilike.%$q%,address.ilike.%$q%');
    }
    final response = await request.order('name', ascending: true);
    return (response as List).map((e) => FactoryModel.fromJson(e)).toList();
  }

  Future<FactoryModel> getFactory(String id) async {
    final response = await _client
        .from('factories')
        .select('*, factory_spsi_types(*), factory_prices(*)')
        .eq('id', id)
        .single();
    return FactoryModel.fromJson(response);
  }

  Future<void> createFactory(FactoryModel factory) async {
    await _client.from('factories').insert(factory.toJson());
    await _replaceTypes(factory);
    await _replacePrices(factory);
  }

  Future<void> updateFactory(FactoryModel factory) async {
    final data = factory.toJson()
      ..remove('id')
      ..remove('created_at');
    await _client.from('factories').update(data).eq('id', factory.id);
    await _replaceTypes(factory);
    await _replacePrices(factory);
  }

  Future<void> deleteFactory(String id) async {
    await _client.from('factory_prices').delete().eq('factory_id', id);
    await _client.from('factory_spsi_types').delete().eq('factory_id', id);
    await _client.from('factories').delete().eq('id', id);
  }

  Future<void> _replaceTypes(FactoryModel factory) async {
    final existing = await _client.from('factory_spsi_types').select('id, name').eq('factory_id', factory.id);
    final existingByName = <String, String>{};
    for (final t in (existing as List)) {
      existingByName[t['name']?.toString().trim().toUpperCase() ?? ''] = t['id'].toString();
    }
    for (final item in factory.spsiTypes) {
      if (item.name.trim().isEmpty) continue;
      final upperName = item.name.trim().toUpperCase();
      final data = item.toJson()..remove('id');
      if (existingByName.containsKey(upperName)) {
        await _client.from('factory_spsi_types').update(data).eq('id', existingByName[upperName]!);
      } else {
        data['factory_id'] = factory.id;
        await _client.from('factory_spsi_types').insert(data);
      }
    }
  }

  Future<void> _replacePrices(FactoryModel factory) async {
    await _client.from('factory_prices').delete().eq('factory_id', factory.id);
    final rows = factory.prices
        .where((item) => item.name.isNotEmpty && item.price > 0)
        .map((item) => item.toJson()..remove('id'))
        .toList();
    if (rows.isNotEmpty) {
      await _client.from('factory_prices').insert(rows);
    }
  }
}
