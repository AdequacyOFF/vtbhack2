class ApiConfig {
  // Team credentials
  static const String clientId = 'team201';
  static const String clientSecret = 'wwYxgibWk0MFale9';

  // Bank base URLs
  static const String vbankBaseUrl = 'https://vbank.open.bankingapi.ru';
  static const String abankBaseUrl = 'https://abank.open.bankingapi.ru';
  static const String sbankBaseUrl = 'https://sbank.open.bankingapi.ru';

  // Yandex Maps API Key
  static const String yandexMapsApiKey = 'ebd640e1-f658-4501-9d60-4995189398e5';

  // Bank identifiers
  static const String vbankCode = 'vbank';
  static const String abankCode = 'abank';
  static const String sbankCode = 'sbank';

  // Bank display names
  static const Map<String, String> bankNames = {
    'vbank': 'VBank',
    'abank': 'ABank',
    'sbank': 'SBank',
  };

  // Bank consent auto-approval
  static const Map<String, bool> bankAutoApproval = {
    'vbank': false,
    'abank': true,
    'sbank': false, // Requires manual approval
  };

  static String getBankBaseUrl(String bankCode) {
    switch (bankCode) {
      case 'vbank':
        return vbankBaseUrl;
      case 'abank':
        return abankBaseUrl;
      case 'sbank':
        return sbankBaseUrl;
      default:
        throw Exception('Unknown bank code: $bankCode');
    }
  }

  static String getBankName(String bankCode) {
    return bankNames[bankCode] ?? bankCode;
  }

  static bool requiresManualApproval(String bankCode) {
    return !(bankAutoApproval[bankCode] ?? false);
  }
}
