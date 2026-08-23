class VehicleModel {
  final String id;
  final String plateNumber;
  final String? driverName;
  final double potonganBp;
  final double? harga;
  final double? uangMinum;
  final bool isSuper;

  // Relasi bayar yang terikat (dari payment_relation_vehicles)
  final String? paymentRelationId;
  final String? paymentRelationName;

  final DateTime createdAt;
  final DateTime updatedAt;

  VehicleModel({
    required this.id,
    required this.plateNumber,
    this.driverName,
    this.potonganBp = 100000,
    this.harga,
    this.uangMinum,
    this.isSuper = false,
    this.paymentRelationId,
    this.paymentRelationName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    final relations = (json['payment_relation_vehicles'] as List?) ?? [];
    String? relId;
    String? relName;
    if (relations.isNotEmpty) {
      final first = relations.first as Map<String, dynamic>;
      relId = first['payment_relation_id']?.toString();
      final rel = first['payment_relations'];
      if (rel is Map && rel['name'] != null) relName = rel['name'].toString();
    }
    return VehicleModel(
      id: json['id'] ?? '',
      plateNumber: json['plate_number'] ?? '',
      driverName: json['driver_name'],
      potonganBp: (json['potongan_bp'] as num?)?.toDouble() ?? 100000,
      harga: (json['harga'] as num?)?.toDouble(),
      uangMinum: (json['uang_minum'] as num?)?.toDouble(),
      isSuper: json['is_super'] == true,
      paymentRelationId: relId,
      paymentRelationName: relName,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plate_number': plateNumber,
      'driver_name': driverName,
      'potongan_bp': potonganBp.toInt(),
      if (harga != null) 'harga': harga!.toInt(),
      if (uangMinum != null) 'uang_minum': uangMinum!.toInt(),
      'is_super': isSuper,
    };
  }
}

/// Opsi ringkas untuk relasi bayar (dropdown inline kendaraan).
class PaymentRelationOption {
  final String id;
  final String name;

  PaymentRelationOption({required this.id, required this.name});

  factory PaymentRelationOption.fromJson(Map<String, dynamic> json) {
    return PaymentRelationOption(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
    );
  }
}