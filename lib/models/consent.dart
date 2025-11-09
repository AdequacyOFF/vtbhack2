class AccountConsent {
  final String consentId;
  final String bankCode;
  final String status;
  final String createdAt;
  final bool autoApproved;

  AccountConsent({
    required this.consentId,
    required this.bankCode,
    required this.status,
    required this.createdAt,
    required this.autoApproved,
  });

  factory AccountConsent.fromJson(Map<String, dynamic> json, String bankCode) {
    return AccountConsent(
      consentId: json['consent_id'] ?? '',
      bankCode: bankCode,
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      autoApproved: json['auto_approved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'consentId': consentId,
      'bankCode': bankCode,
      'status': status,
      'createdAt': createdAt,
      'autoApproved': autoApproved,
    };
  }

  bool get isApproved => status == 'approved' || status == 'active';
  bool get isPending => status == 'pending' || status == 'awaiting_authorization';
}

class PaymentConsent {
  final String consentId;
  final String bankCode;
  final String status;
  final String consentType;
  final bool autoApproved;

  PaymentConsent({
    required this.consentId,
    required this.bankCode,
    required this.status,
    required this.consentType,
    required this.autoApproved,
  });

  factory PaymentConsent.fromJson(Map<String, dynamic> json, String bankCode) {
    return PaymentConsent(
      consentId: json['consent_id'] ?? '',
      bankCode: bankCode,
      status: json['status'] ?? '',
      consentType: json['consent_type'] ?? 'vrp',
      autoApproved: json['auto_approved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'consentId': consentId,
      'bankCode': bankCode,
      'status': status,
      'consentType': consentType,
      'autoApproved': autoApproved,
    };
  }

  bool get isApproved => status == 'approved' || status == 'active';
}

class ProductAgreementConsent {
  final String consentId;
  final String bankCode;
  final String status;
  final bool autoApproved;

  ProductAgreementConsent({
    required this.consentId,
    required this.bankCode,
    required this.status,
    required this.autoApproved,
  });

  factory ProductAgreementConsent.fromJson(Map<String, dynamic> json, String bankCode) {
    return ProductAgreementConsent(
      consentId: json['consent_id'] ?? '',
      bankCode: bankCode,
      status: json['status'] ?? '',
      autoApproved: json['auto_approved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'consentId': consentId,
      'bankCode': bankCode,
      'status': status,
      'autoApproved': autoApproved,
    };
  }

  bool get isApproved => status == 'approved' || status == 'active';
}
