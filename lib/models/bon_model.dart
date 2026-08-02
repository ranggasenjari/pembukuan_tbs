import '../core/enums.dart';

class BonDeduction {
  final String? id;
  final String label;
  final int amount;

  BonDeduction({this.id, required this.label, required this.amount});

  factory BonDeduction.fromJson(Map<String, dynamic> json) {
    return BonDeduction(
      id: json['id'],
      label: json['label'] ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'label': label, 'amount': amount};
  }
}

class BonModel {
  final String id;
  final String? ticketNumber;
  final DateTime bonDate;
  final String plateNumber;
  final String? driverName;
  final String? relationName;
  final String? relationAgentId;
  final String? relationAgentName;
  final String? factoryId;
  final String? factoryName;
  final String? factorySpsiTypeId;
  final String? spsiTypeName;
  final String spsiCalculationMode;
  final double spsiRate;
  final double spsiAmount;
  final String? fruitOrigin;
  final String? notes;

  final double netto1;
  final double netto2;
  final double price;
  final double dp;

  final double biayaBongkar;
  final double bpColt;
  final double pph;
  final double uangMinum;

  final List<BonDeduction> deductions;

  final double total;

  final String? imageUrl;
  final PaymentStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;

  BonModel({
    required this.id,
    this.ticketNumber,
    required this.bonDate,
    required this.plateNumber,
    this.driverName,
    this.relationName,
    this.relationAgentId,
    this.relationAgentName,
    this.factoryId,
    this.factoryName,
    this.factorySpsiTypeId,
    this.spsiTypeName,
    this.spsiCalculationMode = 'PER_KG',
    this.spsiRate = 0,
    this.spsiAmount = 0,
    this.fruitOrigin,
    this.notes,
    required this.netto1,
    required this.netto2,
    required this.price,
    this.dp = 0,
    required this.biayaBongkar,
    required this.bpColt,
    required this.pph,
    required this.uangMinum,
    this.deductions = const [],
    required this.total,
    this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BonModel.fromJson(Map<String, dynamic> json) {
    return BonModel(
      id: json['id'],
      ticketNumber: json['ticket_number'],
      bonDate: DateTime.parse(json['bon_date']),
      plateNumber: json['plate_number'],
      driverName: json['driver_name'],
      relationName: json['relation_name'],
      relationAgentId: json['relation_agent_id'],
      relationAgentName: json['relation_agents']?['name'],
      factoryId: json['factory_id'],
      factoryName: json['factories']?['name'],
      factorySpsiTypeId: json['factory_spsi_type_id'],
      spsiTypeName: json['spsi_type_name'],
      spsiCalculationMode: json['spsi_calculation_mode'] ?? 'PER_KG',
      spsiRate:
          (json['spsi_rate'] as num?)?.toDouble() ??
          (json['biaya_bongkar'] as num?)?.toDouble() ??
          0,
      spsiAmount:
          (json['spsi_amount'] as num?)?.toDouble() ??
          (((json['biaya_bongkar'] as num?)?.toDouble() ?? 0) *
              ((json['netto_1'] as num?)?.toDouble() ?? 0)),
      fruitOrigin: json['fruit_origin'],
      notes: json['notes'],
      netto1: (json['netto_1'] as num?)?.toDouble() ?? 0.0,
      netto2: (json['netto_2'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      dp: (json['dp'] as num?)?.toDouble() ?? 0,
      biayaBongkar: (json['biaya_bongkar'] as num?)?.toDouble() ?? 0.0,
      bpColt: (json['bp_colt'] as num?)?.toDouble() ?? 0.0,
      pph: (json['pph'] as num?)?.toDouble() ?? 0.0,
      uangMinum: (json['uang_minum'] as num?)?.toDouble() ?? 0.0,
      deductions:
          (json['bon_deductions'] as List?)
              ?.map((e) => BonDeduction.fromJson(e))
              .toList() ??
          [],
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'],
      status: PaymentStatusX.fromString(json['status']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ticket_number': ticketNumber,
      'bon_date': bonDate.toIso8601String(),
      'plate_number': plateNumber,
      'driver_name': driverName,
      'relation_name': relationName,
      'relation_agent_id': relationAgentId,
      'factory_id': factoryId,
      'factory_spsi_type_id': factorySpsiTypeId,
      'spsi_type_name': spsiTypeName,
      'spsi_calculation_mode': spsiCalculationMode,
      'spsi_rate': spsiRate.toInt(),
      'spsi_amount': spsiAmount.toInt(),
      'fruit_origin': fruitOrigin,
      'notes': notes,
      'netto_1': netto1.toInt(),
      'netto_2': netto2.toInt(),
      'price': price.toInt(),
      'dp': dp.toInt(),
      'biaya_bongkar': biayaBongkar.toInt(),
      'bp_colt': bpColt.toInt(),
      'pph': pph.toInt(),
      'uang_minum': uangMinum.toInt(),
      'total': total.toInt(),
      'image_url': imageUrl,
      'status': status.value,
    };
  }
}
