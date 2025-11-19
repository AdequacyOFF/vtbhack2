import 'merchant.dart';

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
  final Merchant? merchant;

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
    this.merchant,
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
      merchant: json['merchant'] != null ? Merchant.fromJson(json['merchant']) : null,
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
      if (merchant != null) 'merchant': merchant!.toJson(),
    };
  }

  bool get isCredit => creditDebitIndicator == 'Credit';
  bool get isDebit => creditDebitIndicator == 'Debit';

  double get amountValue => double.tryParse(amount) ?? 0.0;

  String get category {
    // Priority 1: Use MCC code if available
    if (merchant?.mccCode != null) {
      final mccCategory = _mapMccToCategory(merchant!.mccCode!);
      if (mccCategory != null) return mccCategory;
    }

    // Priority 2: Use merchant category from API
    if (merchant?.category != null) {
      final merchantCategory = _mapMerchantCategory(merchant!.category!);
      if (merchantCategory != null) return merchantCategory;
    }

    // Priority 3: Fall back to keyword matching in transactionInformation
    final info = transactionInformation ?? '';
    if (info.contains('🏪')) return 'Продукты';
    if (info.contains('🚌')) return 'Транспорт';
    if (info.contains('🏠')) return 'ЖКХ/Аренда';
    if (info.contains('🎬')) return 'Развлечения';
    if (info.contains('💼')) return 'Зарплата';
    if (info.contains('💰')) return 'Доход';

    // Keyword matching
    final infoLower = info.toLowerCase();
    if (infoLower.contains('еда') || infoLower.contains('ресторан') ||
        infoLower.contains('кафе') || infoLower.contains('продукты')) {
      return 'Еда';
    }
    if (infoLower.contains('транспорт') || infoLower.contains('такси') ||
        infoLower.contains('бензин') || infoLower.contains('топливо')) {
      return 'Транспорт';
    }
    if (infoLower.contains('одежда') || infoLower.contains('магазин') ||
        infoLower.contains('покупки')) {
      return 'Покупки';
    }

    return 'Прочее';
  }

  String? _mapMccToCategory(String mccCode) {
    final code = int.tryParse(mccCode);
    if (code == null) return null;

    // Food & Restaurants
    if ((code >= 5411 && code <= 5499) || (code >= 5811 && code <= 5815)) {
      return 'Еда';
    }
    // Transport
    if ((code >= 3000 && code <= 3299) || (code >= 3351 && code <= 3441) ||
        (code == 4111) || (code == 4112) || (code == 4121) || (code == 4131) ||
        (code >= 4511 && code <= 4582) || (code >= 5511 && code <= 5599)) {
      return 'Транспорт';
    }
    // Shopping
    if ((code >= 5200 && code <= 5399) || (code >= 5611 && code <= 5699) ||
        (code >= 5712 && code <= 5735) || (code >= 5931 && code <= 5999)) {
      return 'Покупки';
    }
    // Entertainment
    if ((code >= 7800 && code <= 7999)) {
      return 'Развлечения';
    }
    // Health
    if ((code == 5912) || (code >= 5975 && code <= 5977) || (code >= 8011 && code <= 8099)) {
      return 'Здоровье';
    }
    // Utilities
    if ((code >= 4812 && code <= 4899) || (code == 4900)) {
      return 'Коммунальные услуги';
    }
    // Education
    if ((code == 5192) || (code == 5942) || (code == 5943) || (code >= 8211 && code <= 8299)) {
      return 'Образование';
    }

    return null;
  }

  String? _mapMerchantCategory(String merchantCategory) {
    final cat = merchantCategory.toLowerCase();
    if (cat == 'food' || cat == 'restaurant' || cat == 'dining') return 'Еда';
    if (cat == 'transport' || cat == 'transportation') return 'Транспорт';
    if (cat == 'shopping' || cat == 'clothing' || cat == 'retail') return 'Покупки';
    if (cat == 'entertainment' || cat == 'recreation') return 'Развлечения';
    if (cat == 'health' || cat == 'medical') return 'Здоровье';
    if (cat == 'utilities' || cat == 'telecom') return 'Коммунальные услуги';
    if (cat == 'education') return 'Образование';
    return null;
  }
}
