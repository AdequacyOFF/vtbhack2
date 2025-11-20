class Contact {
  final String id; // Уникальный ID контакта
  final String clientId; // team201-1, team201-10, etc.
  final String name; // Имя контакта
  final String? bankCode; // vbank, abank, sbank (опционально)
  final String? accountId; // ID счета (опционально)
  final DateTime createdAt;

  Contact({
    required this.id,
    required this.clientId,
    required this.name,
    this.bankCode,
    this.accountId,
    required this.createdAt,
  });

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] ?? '',
      clientId: json['client_id'] ?? '',
      name: json['name'] ?? '',
      bankCode: json['bank_code'],
      accountId: json['account_id'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'name': name,
      'bank_code': bankCode,
      'account_id': accountId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Отображаемое имя с деталями
  String get displayName {
    if (bankCode != null) {
      return '$name (${bankCode!.toUpperCase()})';
    }
    return name;
  }

  // Краткое описание
  String get description {
    if (accountId != null && bankCode != null) {
      return '${bankCode!.toUpperCase()} • ${accountId!.substring(0, 8)}...';
    } else if (bankCode != null) {
      return bankCode!.toUpperCase();
    }
    return clientId;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Contact && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
