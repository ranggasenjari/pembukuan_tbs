class RelationAgentAccount {
  final String? id;
  final String relationAgentId;
  final String accountName;
  final String accountNumber;

  RelationAgentAccount({
    this.id,
    required this.relationAgentId,
    required this.accountName,
    required this.accountNumber,
  });

  factory RelationAgentAccount.fromJson(Map<String, dynamic> json) {
    return RelationAgentAccount(
      id: json['id'],
      relationAgentId: json['relation_agent_id'] ?? '',
      accountName: json['account_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'relation_agent_id': relationAgentId,
      'account_name': accountName,
      'account_number': accountNumber,
    };
  }
}

class RelationAgentModel {
  final String id;
  final String name;
  final String? address;
  final String? contact;
  final List<RelationAgentAccount> accounts;
  final DateTime createdAt;
  final DateTime updatedAt;

  RelationAgentModel({
    required this.id,
    required this.name,
    this.address,
    this.contact,
    this.accounts = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory RelationAgentModel.fromJson(Map<String, dynamic> json) {
    return RelationAgentModel(
      id: json['id'],
      name: json['name'] ?? '',
      address: json['address'],
      contact: json['contact'],
      accounts:
          (json['relation_agent_accounts'] as List?)
              ?.map((e) => RelationAgentAccount.fromJson(e))
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
      'contact': contact,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
