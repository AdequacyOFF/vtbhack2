class BankToken {
  final String accessToken;
  final String tokenType;
  final String clientId;
  final String algorithm;
  final int expiresIn;
  final String bankCode;
  final DateTime createdAt;

  BankToken({
    required this.accessToken,
    required this.tokenType,
    required this.clientId,
    required this.algorithm,
    required this.expiresIn,
    required this.bankCode,
    required this.createdAt,
  });

  factory BankToken.fromJson(Map<String, dynamic> json, String bankCode) {
    return BankToken(
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      clientId: json['client_id'] ?? '',
      algorithm: json['algorithm'] ?? 'HS256',
      expiresIn: json['expires_in'] ?? 86400,
      bankCode: bankCode,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'token_type': tokenType,
      'client_id': clientId,
      'algorithm': algorithm,
      'expires_in': expiresIn,
      'bank_code': bankCode,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isExpired {
    final expiryTime = createdAt.add(Duration(seconds: expiresIn));
    return DateTime.now().isAfter(expiryTime);
  }

  String get authHeader => '$tokenType $accessToken';
}
