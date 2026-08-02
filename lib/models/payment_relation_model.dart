class PaymentRelationAccount {
  final String? id;
  final String paymentRelationId;
  final String bankName;
  final String accountNumber;
  final String accountName;

  PaymentRelationAccount({
    this.id,
    required this.paymentRelationId,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  factory PaymentRelationAccount.fromJson(Map<String, dynamic> json) {
    return PaymentRelationAccount(
      id: json['id'],
      paymentRelationId: json['payment_relation_id'] ?? '',
      bankName: json['bank_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      accountName: json['account_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'payment_relation_id': paymentRelationId,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_name': accountName,
    };
  }
}

class PaymentRelationVehicle {
  final String? id;
  final String paymentRelationId;
  final String vehicleId;
  final VehicleOption? vehicle;

  PaymentRelationVehicle({
    this.id,
    required this.paymentRelationId,
    required this.vehicleId,
    this.vehicle,
  });

  factory PaymentRelationVehicle.fromJson(Map<String, dynamic> json) {
    return PaymentRelationVehicle(
      id: json['id'],
      paymentRelationId: json['payment_relation_id'] ?? '',
      vehicleId: json['vehicle_id'] ?? '',
      vehicle: json['vehicles'] is Map<String, dynamic>
          ? VehicleOption.fromJson(json['vehicles'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'payment_relation_id': paymentRelationId,
      'vehicle_id': vehicleId,
    };
  }
}

class VehicleOption {
  final String id;
  final String plateNumber;
  final String? driverName;

  VehicleOption({
    required this.id,
    required this.plateNumber,
    this.driverName,
  });

  factory VehicleOption.fromJson(Map<String, dynamic> json) {
    return VehicleOption(
      id: json['id'] ?? '',
      plateNumber: json['plate_number'] ?? '',
      driverName: json['driver_name'],
    );
  }
}

class PaymentRelationModel {
  final String id;
  final String name;
  final String? contact;
  final String? address;
  final String? notes;
  final List<PaymentRelationAccount> accounts;
  final List<PaymentRelationVehicle> vehicles;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentRelationModel({
    required this.id,
    required this.name,
    this.contact,
    this.address,
    this.notes,
    this.accounts = const [],
    this.vehicles = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentRelationModel.fromJson(Map<String, dynamic> json) {
    return PaymentRelationModel(
      id: json['id'],
      name: json['name'] ?? '',
      contact: json['contact'],
      address: json['address'],
      notes: json['notes'],
      accounts:
          (json['payment_relation_accounts'] as List?)
              ?.map((e) => PaymentRelationAccount.fromJson(e))
              .toList() ??
          [],
      vehicles:
          (json['payment_relation_vehicles'] as List?)
              ?.map((e) => PaymentRelationVehicle.fromJson(e))
              .toList() ??
          [],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'contact': contact,
      'address': address,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
