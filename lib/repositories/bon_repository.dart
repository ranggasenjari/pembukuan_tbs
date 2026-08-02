import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/bon_model.dart';
import '../../models/nota_model.dart';
import '../../models/payment_model.dart';

class BonRepository {
  final SupabaseClient _client;

  BonRepository(this._client);

  Future<List<BonModel>> getBons({
    DateTime? startDate,
    DateTime? endDate,
    String? driverQuery,
    String? factoryId,
  }) async {
    var query = _client
        .from('bons')
        .select('*, bon_deductions(*), factories(name), relation_agents(name)');

    if (startDate != null) {
      query = query.gte('bon_date', startDate.toIso8601String().split('T')[0]);
    }
    if (endDate != null) {
      final nextDay = DateTime.utc(endDate.year, endDate.month, endDate.day + 1);
      query = query.lt('bon_date', nextDay.toIso8601String().split('T')[0]);
    }
    if (driverQuery != null && driverQuery.isNotEmpty) {
      query = query.or(
        'driver_name.ilike.%$driverQuery%,plate_number.ilike.%$driverQuery%,relation_name.ilike.%$driverQuery%',
      );
    }
    if (factoryId != null && factoryId.isNotEmpty) {
      query = query.eq('factory_id', factoryId);
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).map((e) => BonModel.fromJson(e)).toList();
  }

  Future<BonModel> createBon(
    BonModel bon,
    Uint8List? imageBytes,
    String? fileName, {
    String? existingImageUrl,
  }) async {
    String? imageUrl = existingImageUrl;
    if (imageUrl == null && imageBytes != null && fileName != null) {
      final path = 'bons/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      await _client.storage.from('receipts').uploadBinary(path, imageBytes);
      imageUrl = _client.storage.from('receipts').getPublicUrl(path);
    }

    final bonData = bon.toJson();
    if (imageUrl != null) {
      bonData['image_url'] = imageUrl;
    }
    bonData.remove('id');

    final response = await _client
        .from('bons')
        .insert(bonData)
        .select()
        .single();
    final createdBon = BonModel.fromJson(response);

    // Save deductions if any
    if (bon.deductions.isNotEmpty) {
      final deductionsData = bon.deductions
          .map(
            (d) => {
              'bon_id': createdBon.id,
              'label': d.label,
              'amount': d.amount,
            },
          )
          .toList();
      await _client.from('bon_deductions').insert(deductionsData);
    }

    // Refresh to get deductions back
    return (await _client
        .from('bons')
        .select('*, bon_deductions(*), factories(name), relation_agents(name)')
        .eq('id', createdBon.id)
        .single()
        .then((v) => BonModel.fromJson(v)));
  }

  Future<void> quickUpdateBon(String id, Map<String, dynamic> changes) async {
    final current = await _client
        .from('bons')
        .select('*, bon_deductions(amount)')
        .eq('id', id)
        .single();
    if (current['status'] == 'LUNAS') {
      throw Exception('Bon sudah lunas, tidak dapat diedit.');
    }

    final merged = Map<String, dynamic>.from(current);
    merged.addAll(changes);

    final netto1 = (merged['netto_1'] as num?)?.toInt() ?? 0;
    final netto2 = (merged['netto_2'] as num?)?.toInt() ?? 0;
    final price = (merged['price'] as num?)?.toInt() ?? 0;
    final dp = (merged['dp'] as num?)?.toInt() ?? 0;
    final bpColt = (merged['bp_colt'] as num?)?.toInt() ?? 0;
    final pph = (merged['pph'] as num?)?.toInt() ?? 0;
    final uangMinum = (merged['uang_minum'] as num?)?.toInt() ?? 0;
    final deductionTotal = ((merged['bon_deductions'] as List?) ?? [])
        .fold<int>(0, (sum, d) => sum + ((d['amount'] as num?)?.toInt() ?? 0));
    final spsiMode = (merged['spsi_calculation_mode'] as String?) ?? 'PER_KG';
    final spsiRate =
        (merged['spsi_rate'] as num?)?.toInt() ??
        (merged['biaya_bongkar'] as num?)?.toInt() ??
        12;
    final subtotal = price * netto2;
    final totalBiayaBongkar = spsiMode == 'FIX' ? spsiRate : spsiRate * netto1;
    final total =
        subtotal -
        dp -
        totalBiayaBongkar -
        bpColt -
        pph -
        uangMinum -
        deductionTotal;

    final data = <String, dynamic>{
      'netto_2': netto2,
      'price': price,
      'bp_colt': bpColt,
      'pph': pph,
      'uang_minum': uangMinum,
      'spsi_amount': totalBiayaBongkar,
      'total': total,
    };

    await _client.from('bons').update(data).eq('id', id);
  }

  Future<void> updateRaw(String id, Map<String, dynamic> data) async {
    await _client.from('bons').update(data).eq('id', id);
  }

  Future<void> updateBon(BonModel bon) async {
    // 1. Check current status in DB
    final current = await _client
        .from('bons')
        .select('status')
        .eq('id', bon.id)
        .single();
    if (current['status'] == 'LUNAS') {
      throw Exception('Bon sudah lunas, tidak dapat diedit.');
    }

    final data = bon.toJson();
    data.remove('id');
    await _client.from('bons').update(data).eq('id', bon.id);

    // Update deductions: Delete and Re-insert for simplicity
    await _client.from('bon_deductions').delete().eq('bon_id', bon.id);
    if (bon.deductions.isNotEmpty) {
      final deductionsData = bon.deductions
          .map((d) => {'bon_id': bon.id, 'label': d.label, 'amount': d.amount})
          .toList();
      await _client.from('bon_deductions').insert(deductionsData);
    }
  }

  Future<void> deleteBon(String id) async {
    // 1. Check current status in DB
    final current = await _client
        .from('bons')
        .select('status, image_url')
        .eq('id', id)
        .single();
    if (current['status'] != 'BELUM_DIBAYAR') {
      throw Exception('Bon sudah dibuat nota atau lunas, tidak dapat dihapus.');
    }

    // 2. Hapus file dari bucket jika ada
    final imageUrl = current['image_url'] as String?;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final pathMatch = RegExp(
        r'/object/public/[^/]+/(.+)$',
      ).firstMatch(imageUrl);
      if (pathMatch != null) {
        final filePath = pathMatch.group(1)!;
        await _client.storage
            .from('receipts')
            .remove([filePath])
            .catchError((_) {});
      }
    }

    await _client.from('bons').delete().eq('id', id);
  }

  Future<Map<String, List<dynamic>>> getRelatedRecords(String bonId) async {
    // 1. Get Notas via nota_items
    final notaItems = await _client
        .from('nota_items')
        .select('notas(*)')
        .eq('bon_id', bonId);

    final notasData = notaItems.map((e) => e['notas']).toList();

    if (notasData.isEmpty) {
      return {'notas': [], 'payments': []};
    }

    final notaIds = notasData.map((i) => i['id'] as String).toList();

    // 2. Get Payments for those notas
    final paymentsResponse = await _client
        .from('payments')
        .select('*, notas(invoice_number)')
        .filter('invoice_id', 'in', notaIds);

    return {
      'notas': notasData.map((e) => NotaModel.fromJson(e)).toList(),
      'payments': (paymentsResponse as List)
          .map((e) => PaymentModel.fromJson(e))
          .toList(),
    };
  }

  Future<double> getLatestPrice() async {
    try {
      final response = await _client
          .from('bons')
          .select('price')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['price'] != null) {
        return (response['price'] as num).toDouble();
      }
    } catch (_) {
      // Return 0 if fails
    }
    return 0.0;
  }
}
