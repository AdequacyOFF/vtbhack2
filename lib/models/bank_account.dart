class BankAccount {
  final String accountId;
  final String bankCode;
  final String status;
  final String currency;
  final String accountType;
  final String accountSubType;
  final String? nickname;
  final String? description;
  final String openingDate;
  final String? identification;
  final String? name;
  final double? balance;
  final double? availableBalance;

  BankAccount({
    required this.accountId,
    required this.bankCode,
    required this.status,
    required this.currency,
    required this.accountType,
    required this.accountSubType,
    this.nickname,
    this.description,
    required this.openingDate,
    this.identification,
    this.name,
    this.balance,
    this.availableBalance,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json, String bankCode) {
    // Extract account identification if available
    String? identification;
    String? name;
    if (json['account'] != null && json['account'] is List && (json['account'] as List).isNotEmpty) {
      final accountInfo = json['account'][0];
      identification = accountInfo['identification'];
      name = accountInfo['name'];
    }

    return BankAccount(
      accountId: json['accountId'] ?? '',
      bankCode: bankCode,
      status: json['status'] ?? '',
      currency: json['currency'] ?? 'RUB',
      accountType: json['accountType'] ?? '',
      accountSubType: json['accountSubType'] ?? '',
      nickname: json['nickname'],
      description: json['description'],
      openingDate: json['openingDate'] ?? '',
      identification: identification,
      name: name,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accountId': accountId,
      'bankCode': bankCode,
      'status': status,
      'currency': currency,
      'accountType': accountType,
      'accountSubType': accountSubType,
      'nickname': nickname,
      'description': description,
      'openingDate': openingDate,
      'identification': identification,
      'name': name,
      'balance': balance,
      'availableBalance': availableBalance,
    };
  }

  BankAccount copyWith({
    double? balance,
    double? availableBalance,
  }) {
    return BankAccount(
      accountId: accountId,
      bankCode: bankCode,
      status: status,
      currency: currency,
      accountType: accountType,
      accountSubType: accountSubType,
      nickname: nickname,
      description: description,
      openingDate: openingDate,
      identification: identification,
      name: name,
      balance: balance ?? this.balance,
      availableBalance: availableBalance ?? this.availableBalance,
    );
  }

  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) return nickname!;
    if (accountSubType.isNotEmpty) return accountSubType;
    return accountType;
  }
}
