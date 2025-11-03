class BankProduct {
  final String productId;
  final String productType;
  final String productName;
  final String description;
  final String? interestRate;
  final String? minAmount;
  final String? maxAmount;
  final int? termMonths;
  final String bankCode;

  BankProduct({
    required this.productId,
    required this.productType,
    required this.productName,
    required this.description,
    this.interestRate,
    this.minAmount,
    this.maxAmount,
    this.termMonths,
    required this.bankCode,
  });

  factory BankProduct.fromJson(Map<String, dynamic> json, String bankCode) {
    return BankProduct(
      productId: json['productId'] ?? '',
      productType: json['productType'] ?? '',
      productName: json['productName'] ?? '',
      description: json['description'] ?? '',
      interestRate: json['interestRate']?.toString(),
      minAmount: json['minAmount']?.toString(),
      maxAmount: json['maxAmount']?.toString(),
      termMonths: json['termMonths'],
      bankCode: bankCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productType': productType,
      'productName': productName,
      'description': description,
      'interestRate': interestRate,
      'minAmount': minAmount,
      'maxAmount': maxAmount,
      'termMonths': termMonths,
      'bankCode': bankCode,
    };
  }

  bool get isDeposit => productType == 'deposit';
  bool get isLoan => productType == 'loan';
  bool get isCard => productType == 'card' || productType == 'credit_card';

  double? get interestRateValue => double.tryParse(interestRate ?? '');
  double? get minAmountValue => double.tryParse(minAmount ?? '');
  double? get maxAmountValue => double.tryParse(maxAmount ?? '');
}
