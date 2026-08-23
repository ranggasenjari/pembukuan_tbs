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

class PaymentRelationDatedRow {
  final String? id;
  final String paymentRelationId;
  final DateTime tanggal;
  final int amount;
  final String? notes;

  PaymentRelationDatedRow({
    this.id,
    required this.paymentRelationId,
    required this.tanggal,
    required this.amount,
    this.notes,
  });

  factory PaymentRelationDatedRow.fromJson(Map<String, dynamic> json) {
    return PaymentRelationDatedRow(
      id: json['id'],
      paymentRelationId: json['payment_relation_id'] ?? '',
      tanggal: DateTime.tryParse(json['tanggal'] ?? '') ?? DateTime.now(),
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'payment_relation_id': paymentRelationId,
      'tanggal': tanggal.toIso8601String().split('T')[0],
      'amount': amount,
      'notes': notes,
    };
  }
}

class PaymentRelationGiringan {
  final String? id;
  final String paymentRelationId;
  final String name;

  PaymentRelationGiringan({
    this.id,
    required this.paymentRelationId,
    required this.name,
  });

  factory PaymentRelationGiringan.fromJson(Map<String, dynamic> json) {
    return PaymentRelationGiringan(
      id: json['id'],
      paymentRelationId: json['payment_relation_id'] ?? '',
      name: json['name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'payment_relation_id': paymentRelationId,
      'name': name,
    };
  }
}

class PaymentRelationModel {
  final String id;
  final String name;
  final String? contact;
  final String? address;
  final String? notes;
  final int? fee;
  final int? potonganBp;
  final int? harga;
  final int? uangMinum;
  final List<PaymentRelationAccount> accounts;
  final List<PaymentRelationVehicle> vehicles;
  final List<PaymentRelationDatedRow> hutang;
  final List<PaymentRelationDatedRow> rolling;
  final List<PaymentRelationGiringan> giringan;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentRelationModel({
    required this.id,
    required this.name,
    this.contact,
    this.address,
    this.notes,
    this.fee,
    this.potonganBp,
    this.harga,
    this.uangMinum,
    this.accounts = const [],
    this.vehicles = const [],
    this.hutang = const [],
    this.rolling = const [],
    this.giringan = const [],
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
      fee: (json['fee'] as num?)?.toInt(),
      potonganBp: (json['potongan_bp'] as num?)?.toInt(),
      harga: (json['harga'] as num?)?.toInt(),
      uangMinum: (json['uang_minum'] as num?)?.toInt(),
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
      hutang:
          (json['payment_relation_hutang'] as List?)
              ?.map((e) => PaymentRelationDatedRow.fromJson(e))
              .toList() ??
          [],
      rolling:
          (json['payment_relation_rolling'] as List?)
              ?.map((e) => PaymentRelationDatedRow.fromJson(e))
              .toList() ??
          [],
      giringan:
          (json['payment_relation_giringan'] as List?)
              ?.map((e) => PaymentRelationGiringan.fromJson(e))
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
      'fee': fee,
      'potongan_bp': potonganBp,
      'harga': harga,
      'uang_minum': uangMinum,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
