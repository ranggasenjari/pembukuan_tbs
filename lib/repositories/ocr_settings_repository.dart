import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/ocr_settings_model.dart';

class OcrSettingsRepository {
  static const _settingKey = 'ocr';
  final SupabaseClient _client;

  OcrSettingsRepository(this._client);

  Future<OcrSettingsModel> getSettings() async {
    try {
      final row = await _client
          .from('app_settings')
          .select('value')
          .eq('key', _settingKey)
          .maybeSingle();
      return OcrSettingsModel.fromJson(
        row == null ? null : Map<String, dynamic>.from(row['value'] ?? {}),
      );
    } on PostgrestException catch (e) {
      if (e.code == '42P01' || e.code == 'PGRST205') {
        return OcrSettingsModel.defaults();
      }
      rethrow;
    }
  }

  Future<OcrSettingsModel> saveSettings({
    required OcrSettingsModel current,
    required OcrMode mode,
    required String webhookUrl,
    required String webhookKey,
    required String mistralApiKey,
    required String mistralPrompt,
    required String mistralOutputSchema,
    Map<String, OcrFactorySettings>? factorySettings,
  }) async {
    json.decode(mistralOutputSchema);
    for (final settings in (factorySettings ?? current.factorySettings).values) {
      if (settings.outputSchema != null && settings.outputSchema!.trim().isNotEmpty) {
        json.decode(settings.outputSchema!);
      }
    }
    final next = current.copyWith(
      mode: mode,
      webhookUrl: webhookUrl.trim().isEmpty
          ? OcrSettingsModel.defaults().webhookUrl
          : webhookUrl.trim(),
      webhookKey: webhookKey.trim().isEmpty
          ? current.webhookKey
          : webhookKey.trim(),
      mistralApiKey: mistralApiKey.trim().isEmpty
          ? current.mistralApiKey
          : mistralApiKey.trim(),
      mistralPrompt: mistralPrompt.trim().isEmpty
          ? OcrSettingsModel.defaults().mistralPrompt
          : mistralPrompt.trim(),
      mistralOutputSchema: mistralOutputSchema.trim(),
      factorySettings: factorySettings ?? current.factorySettings,
    );

    await _client.from('app_settings').upsert({
      'key': _settingKey,
      'value': next.toJson(),
    });

    return next;
  }
}
