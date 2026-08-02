class FactorySpsiType {
  final String? id;
  final String factoryId;
  final String name;
  final String calculationMode;
  final double amount;

  FactorySpsiType({
    this.id,
    required this.factoryId,
    required this.name,
    required this.calculationMode,
    required this.amount,
  });

  factory FactorySpsiType.fromJson(Map<String, dynamic> json) {
    return FactorySpsiType(
      id: json['id'],
      factoryId: json['factory_id'] ?? '',
      name: json['name'] ?? '',
      calculationMode: json['calculation_mode'] ?? 'PER_KG',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'factory_id': factoryId,
      'name': name,
      'calculation_mode': calculationMode,
      'amount': amount.toInt(),
    };
  }
}

class FactoryPrice {
  final String? id;
  final String factoryId;
  final String name;
  final double price;
  final bool isDefault;

  FactoryPrice({
    this.id,
    required this.factoryId,
    required this.name,
    required this.price,
    this.isDefault = false,
  });

  factory FactoryPrice.fromJson(Map<String, dynamic> json) {
    return FactoryPrice(
      id: json['id'],
      factoryId: json['factory_id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      isDefault: json['is_default'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'factory_id': factoryId,
      'name': name,
      'price': price.toInt(),
      'is_default': isDefault,
    };
  }
}

class FactoryModel {
  final String id;
  final String name;
  final String? address;
  final List<FactorySpsiType> spsiTypes;
  final List<FactoryPrice> prices;
  final DateTime createdAt;
  final DateTime updatedAt;

  FactoryModel({
    required this.id,
    required this.name,
    this.address,
    this.spsiTypes = const [],
    this.prices = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory FactoryModel.fromJson(Map<String, dynamic> json) {
    return FactoryModel(
      id: json['id'],
      name: json['name'] ?? '',
      address: json['address'],
      spsiTypes:
          (json['factory_spsi_types'] as List?)
              ?.map((e) => FactorySpsiType.fromJson(e))
              .toList() ??
          [],
      prices:
          (json['factory_prices'] as List?)
              ?.map((e) => FactoryPrice.fromJson(e))
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
      'address': address,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
