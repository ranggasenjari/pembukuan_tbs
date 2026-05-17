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
  final String? fruitOrigin;

  final double netto1;
  final double netto2;
  final double price;
  final double dp;
  final double potLain;

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
    this.fruitOrigin,
    required this.netto1,
    required this.netto2,
    required this.price,
    this.dp = 0,
    required this.biayaBongkar,
    required this.bpColt,
    required this.pph,
    required this.uangMinum,
    this.potLain = 0,
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
      fruitOrigin: json['fruit_origin'],
      netto1: (json['netto_1'] as num?)?.toDouble() ?? 0.0,
      netto2: (json['netto_2'] as num?)?.toDouble() ?? 0.0,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      dp: (json['dp'] as num?)?.toDouble() ?? 0,
      biayaBongkar: (json['biaya_bongkar'] as num?)?.toDouble() ?? 0.0,
      bpColt: (json['bp_colt'] as num?)?.toDouble() ?? 0.0,
      pph: (json['pph'] as num?)?.toDouble() ?? 0.0,
      uangMinum: (json['uang_minum'] as num?)?.toDouble() ?? 0.0,
      potLain: (json['pot_lain'] as num?)?.toDouble() ?? 0,
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
      'fruit_origin': fruitOrigin,
      'netto_1': netto1.toInt(),
      'netto_2': netto2.toInt(),
      'price': price.toInt(),
      'dp': dp.toInt(),
      'biaya_bongkar': biayaBongkar.toInt(),
      'bp_colt': bpColt.toInt(),
      'pph': pph.toInt(),
      'uang_minum': uangMinum.toInt(),
      'pot_lain': potLain.toInt(),
      'total': total.toInt(),
      'image_url': imageUrl,
      'status': status.value,
    };
  }
}
