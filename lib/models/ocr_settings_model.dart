import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

enum OcrMode { webhook, internal }

extension OcrModeX on OcrMode {
  String get value => this == OcrMode.internal ? 'internal' : 'webhook';

  static OcrMode fromString(String? value) {
    return value == 'internal' ? OcrMode.internal : OcrMode.webhook;
  }
}

class OcrSettingsModel {
  final OcrMode mode;
  final String webhookUrl;
  final String webhookKey;
  final String mistralApiKey;
  final String mistralPrompt;
  final String mistralOutputSchema;

  const OcrSettingsModel({
    required this.mode,
    required this.webhookUrl,
    this.webhookKey = '',
    this.mistralApiKey = '',
    required this.mistralPrompt,
    required this.mistralOutputSchema,
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
    );
  }

  OcrSettingsModel copyWith({
    OcrMode? mode,
    String? webhookUrl,
    String? webhookKey,
    String? mistralApiKey,
    String? mistralPrompt,
    String? mistralOutputSchema,
  }) {
    return OcrSettingsModel(
      mode: mode ?? this.mode,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      webhookKey: webhookKey ?? this.webhookKey,
      mistralApiKey: mistralApiKey ?? this.mistralApiKey,
      mistralPrompt: mistralPrompt ?? this.mistralPrompt,
      mistralOutputSchema: mistralOutputSchema ?? this.mistralOutputSchema,
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
