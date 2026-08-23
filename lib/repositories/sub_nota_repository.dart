import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sub_nota_model.dart';
import 'interfaces.dart';

class SubNotaRepository implements ISubNotaRepository {
  final SupabaseClient _client;

  SubNotaRepository(this._client);

  @override
  Future<List<SubNotaModel>> getByBon(String bonId) async {
    final response = await _client
        .from('sub_notas')
        .select()
        .eq('bon_id', bonId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => SubNotaModel.fromJson(e)).toList();
  }

  @override
  Future<SubNotaModel> create({
    required String bonId,
    required String name,
    required int pricePerKg,
    int? netto2,
    String? notes,
  }) async {
    // Ambil netto_2 authoritative dari bon bila tidak dikirim.
    final effectiveNetto2 = netto2 ?? await _fetchBonNetto2(bonId);
    final amount = effectiveNetto2 * pricePerKg;

    final response = await _client
        .from('sub_notas')
        .insert({
          'bon_id': bonId,
          'name': name.toUpperCase().trim(),
          'price_per_kg': pricePerKg,
          'netto_2': effectiveNetto2,
          'amount': amount,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        })
        .select()
        .single();
    return SubNotaModel.fromJson(response);
  }

  @override
  Future<void> delete(String id) async {
    await _client.from('sub_notas').delete().eq('id', id);
  }

  Future<int> _fetchBonNetto2(String bonId) async {
    final response = await _client
        .from('bons')
        .select('netto_2')
        .eq('id', bonId)
        .single();
    return (response['netto_2'] as num?)?.toInt() ?? 0;
  }
}