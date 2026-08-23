import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

enum OcrMode { webhook, internal }

extension OcrModeX on OcrMode {
  String get value => this == OcrMode.internal ? 'internal' : 'webhook';

  static OcrMode fromString(String? value) {
    return value == 'internal' ? OcrMode.internal : OcrMode.webhook;
  }
}

/// Prompt & output schema khusus untuk satu pabrik tertentu pada Internal OCR.
/// Karena format bon tiap pabrik berbeda, pengaturan ini memungkinkan setiap
/// pabrik memakai prompt dan schema yang sesuai.
class OcrFactorySettings {
  final String factoryId;
  final String? factoryName;
  final String? prompt;
  final String? outputSchema;

  const OcrFactorySettings({
    required this.factoryId,
    this.factoryName,
    this.prompt,
    this.outputSchema,
  });

  factory OcrFactorySettings.fromJson(Map<String, dynamic> json) {
    return OcrFactorySettings(
      factoryId: json['factory_id']?.toString() ?? '',
      factoryName: json['factory_name']?.toString(),
      prompt: json['prompt']?.toString(),
      outputSchema: json['output_schema']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'factory_id': factoryId,
      'factory_name': factoryName,
      'prompt': prompt,
      'output_schema': outputSchema,
    };
  }
}

class OcrSettingsModel {
  final OcrMode mode;
  final String webhookUrl;
  final String webhookKey;
  final String mistralApiKey;
  final String mistralPrompt;
  final String mistralOutputSchema;

  /// Pengaturan prompt & schema khusus per pabrik, key = factory id.
  final Map<String, OcrFactorySettings> factorySettings;

  const OcrSettingsModel({
    required this.mode,
    required this.webhookUrl,
    this.webhookKey = '',
    this.mistralApiKey = '',
    required this.mistralPrompt,
    required this.mistralOutputSchema,
    this.factorySettings = const {},
  });

  factory OcrSettingsModel.defaults() {
    final webhookUrl =
        dotenv.env['OCR_WEBHOOK_URL'] ??
        dotenv.env['N8N_WEBHOOK_URL'] ??
        'https://n8n.langkatkab.go.id/webhook-test/bon';
    return OcrSettingsModel(
      mode: OcrMode.webhook,
      webhookUrl: webhookUrl,
      mistralPrompt: defaultMistralPrompt,
      mistralOutputSchema: const JsonEncoder.withIndent(
        '  ',
      ).convert(defaultMistralOutputSchema),
    );
  }

  factory OcrSettingsModel.fromJson(Map<String, dynamic>? json) {
    final defaults = OcrSettingsModel.defaults();
    if (json == null) return defaults;
    final schema = json['mistral_output_schema'];
    return OcrSettingsModel(
      mode: OcrModeX.fromString(json['mode']?.toString()),
      webhookUrl: (json['webhook_url']?.toString().trim().isNotEmpty ?? false)
          ? json['webhook_url'].toString().trim()
          : defaults.webhookUrl,
      webhookKey: json['webhook_key']?.toString() ?? '',
      mistralApiKey: json['mistral_api_key']?.toString() ?? '',
      mistralPrompt:
          (json['mistral_prompt']?.toString().trim().isNotEmpty ?? false)
          ? json['mistral_prompt'].toString()
          : defaults.mistralPrompt,
      mistralOutputSchema: schema is String
          ? schema
          : const JsonEncoder.withIndent(
              '  ',
            ).convert(schema ?? defaultMistralOutputSchema),
      factorySettings: _parseFactorySettings(json['factory_settings']),
    );
  }

  static Map<String, OcrFactorySettings> _parseFactorySettings(dynamic value) {
    final map = <String, OcrFactorySettings>{};
    if (value is Map) {
      for (final entry in value.entries) {
        final raw = entry.value;
        if (raw is Map) {
          final item = Map<String, dynamic>.from(raw)
            ..putIfAbsent('factory_id', () => entry.key.toString());
          final settings = OcrFactorySettings.fromJson(item);
          if (settings.factoryId.isNotEmpty) {
            map[settings.factoryId] = settings;
          }
        }
      }
    } else if (value is List) {
      for (final raw in value) {
        if (raw is Map) {
          final settings = OcrFactorySettings.fromJson(
            Map<String, dynamic>.from(raw),
          );
          if (settings.factoryId.isNotEmpty) {
            map[settings.factoryId] = settings;
          }
        }
      }
    }
    return map;
  }

  OcrSettingsModel copyWith({
    OcrMode? mode,
    String? webhookUrl,
    String? webhookKey,
    String? mistralApiKey,
    String? mistralPrompt,
    String? mistralOutputSchema,
    Map<String, OcrFactorySettings>? factorySettings,
  }) {
    return OcrSettingsModel(
      mode: mode ?? this.mode,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      webhookKey: webhookKey ?? this.webhookKey,
      mistralApiKey: mistralApiKey ?? this.mistralApiKey,
      mistralPrompt: mistralPrompt ?? this.mistralPrompt,
      mistralOutputSchema: mistralOutputSchema ?? this.mistralOutputSchema,
      factorySettings: factorySettings ?? this.factorySettings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode.value,
      'webhook_url': webhookUrl,
      'webhook_key': webhookKey,
      'mistral_api_key': mistralApiKey,
      'mistral_prompt': mistralPrompt,
      'mistral_output_schema': mistralOutputSchema,
      'factory_settings': {
        for (final entry in factorySettings.entries) entry.key: entry.value.toJson(),
      },
    };
  }
}

const defaultMistralPrompt =
    'You are a document parsing assistant. Extract structured data from the OCR text. '
    'Return JSON only. Format date as YYYY-MM-DD. Format number fields as integers with no punctuation.';

const defaultMistralOutputSchema = {
  'type': 'json_schema',
  'json_schema': {
    'name': 'slip_timbangan',
    'strict': true,
    'schema': {
      'type': 'object',
      'additionalProperties': false,
      'properties': {
        'factory_name': {
          'type': ['string', 'null'],
        },
        'ticket_number': {
          'type': ['string', 'null'],
        },
        'bon_date': {
          'type': ['string', 'null'],
        },
        'plate_number': {
          'type': ['string', 'null'],
        },
        'relation_name': {
          'type': ['string', 'null'],
        },
        'produk': {
          'type': ['string', 'null'],
        },
        'driver_name': {
          'type': ['string', 'null'],
        },
        'fruit_origin': {
          'type': ['string', 'null'],
        },
        'netto_1': {
          'type': ['integer', 'null'],
        },
        'netto_2': {
          'type': ['integer', 'null'],
        },
        'is_super': {
          'type': ['boolean', 'null'],
        },
      },
      'required': [
        'factory_name',
        'ticket_number',
        'bon_date',
        'plate_number',
        'relation_name',
        'produk',
        'driver_name',
        'fruit_origin',
        'netto_1',
        'netto_2',
        'is_super',
      ],
    },
  },
};
