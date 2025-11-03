class BankTransaction {
  final String transactionId;
  final String accountId;
  final String amount;
  final String currency;
  final String creditDebitIndicator; // Credit or Debit
  final String status;
  final String bookingDateTime;
  final String valueDateTime;
  final String? transactionInformation;
  final String? bankTransactionCode;

  BankTransaction({
    required this.transactionId,
    required this.accountId,
    required this.amount,
    required this.currency,
    required this.creditDebitIndicator,
    required this.status,
    required this.bookingDateTime,
    required this.valueDateTime,
    this.transactionInformation,
    this.bankTransactionCode,
  });

  factory BankTransaction.fromJson(Map<String, dynamic> json) {
    return BankTransaction(
      transactionId: json['transactionId'] ?? '',
      accountId: json['accountId'] ?? '',
      amount: json['amount']?['amount']?.toString() ?? '0',
      currency: json['amount']?['currency'] ?? 'RUB',
      creditDebitIndicator: json['creditDebitIndicator'] ?? '',
      status: json['status'] ?? '',
      bookingDateTime: json['bookingDateTime'] ?? '',
      valueDateTime: json['valueDateTime'] ?? '',
      transactionInformation: json['transactionInformation'],
      bankTransactionCode: json['bankTransactionCode']?['code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transactionId': transactionId,
      'accountId': accountId,
      'amount': amount,
      'currency': currency,
      'creditDebitIndicator': creditDebitIndicator,
      'status': status,
      'bookingDateTime': bookingDateTime,
      'valueDateTime': valueDateTime,
      'transactionInformation': transactionInformation,
      'bankTransactionCode': bankTransactionCode,
    };
  }

  bool get isCredit => creditDebitIndicator == 'Credit';
  bool get isDebit => creditDebitIndicator == 'Debit';

  double get amountValue => double.tryParse(amount) ?? 0.0;

  String get category {
    final info = transactionInformation ?? '';
    if (info.contains('🏪')) return 'Продукты';
    if (info.contains('🚌')) return 'Транспорт';
    if (info.contains('🏠')) return 'ЖКХ/Аренда';
    if (info.contains('🎬')) return 'Развлечения';
    if (info.contains('💼')) return 'Зарплата';
    if (info.contains('💰')) return 'Доход';
    return 'Прочее';
  }
}
