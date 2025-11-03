import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/bank_token.dart';
import '../models/bank_account.dart';
import '../models/transaction.dart';
import '../models/product.dart';
import '../models/consent.dart';

class BankApiService {
  final String bankCode;
  BankToken? _token;

  BankApiService(this.bankCode);

  String get baseUrl => ApiConfig.getBankBaseUrl(bankCode);

  // Authentication
  Future<BankToken> getBankToken() async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/bank-token?client_id=${ApiConfig.clientId}&client_secret=${ApiConfig.clientSecret}'),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      _token = BankToken.fromJson(json, bankCode);
      return _token!;
    } else {
      throw Exception('Failed to get bank token: ${response.body}');
    }
  }

  Future<BankToken> ensureValidToken() async {
    if (_token == null || _token!.isExpired) {
      return await getBankToken();
    }
    return _token!;
  }

  Map<String, String> _authHeaders(BankToken token) {
    return {
      'Authorization': 'Bearer ${token.accessToken}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  // Consents
  Future<AccountConsent> createAccountConsent(String clientId) async {
    final token = await ensureValidToken();

    final body = {
      'client_id': clientId,
      'permissions': [
        'ReadAccountsDetail',
        'ReadBalances',
        'ReadTransactionsDetail',
      ],
      'reason': 'Агрегация счетов для мультибанк-приложения',
      'requesting_bank': ApiConfig.clientId,
      'requesting_bank_name': 'VTB Hack App',
    };

    final response = await http.post(
      Uri.parse('$baseUrl/account-consents/request'),
      headers: {
        ..._authHeaders(token),
        'x-requesting-bank': ApiConfig.clientId,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return AccountConsent.fromJson(jsonDecode(response.body), bankCode);
    } else {
      throw Exception('Failed to create account consent: ${response.body}');
    }
  }

  Future<PaymentConsent> createPaymentConsent(String clientId, String debtorAccount) async {
    final token = await ensureValidToken();

    final body = {
      'requesting_bank': ApiConfig.clientId,
      'client_id': clientId,
      'consent_type': 'vrp',
      'debtor_account': debtorAccount,
      'vrp_max_individual_amount': 1000000.00,
      'vrp_daily_limit': 3000000.00,
      'vrp_monthly_limit': 50000000.00,
      'valid_until': '2026-12-31T23:59:59',
    };

    final response = await http.post(
      Uri.parse('$baseUrl/payment-consents/request'),
      headers: {
        ..._authHeaders(token),
        'x-requesting-bank': ApiConfig.clientId,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return PaymentConsent.fromJson(jsonDecode(response.body), bankCode);
    } else {
      throw Exception('Failed to create payment consent: ${response.body}');
    }
  }

  Future<ProductAgreementConsent> createProductAgreementConsent(String clientId) async {
    final token = await ensureValidToken();

    final body = {
      'requesting_bank': ApiConfig.clientId,
      'client_id': clientId,
      'read_product_agreements': true,
      'open_product_agreements': true,
      'close_product_agreements': true,
      'allowed_product_types': ['deposit', 'card', 'loan'],
      'max_amount': 10000000.00,
      'valid_until': '2026-12-31T23:59:59',
      'reason': 'Управление продуктами через мультибанк-приложение',
    };

    final response = await http.post(
      Uri.parse('$baseUrl/product-agreement-consents/request?client_id=$clientId'),
      headers: _authHeaders(token),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return ProductAgreementConsent.fromJson(jsonDecode(response.body), bankCode);
    } else {
      throw Exception('Failed to create product agreement consent: ${response.body}');
    }
  }

  // Accounts
  Future<List<BankAccount>> getAccounts(String clientId, String consentId) async {
    final token = await ensureValidToken();

    final response = await http.get(
      Uri.parse('$baseUrl/accounts?client_id=$clientId'),
      headers: {
        ..._authHeaders(token),
        'x-consent-id': consentId,
        'x-requesting-bank': ApiConfig.clientId,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final accounts = (json['data']['account'] as List)
          .map((account) => BankAccount.fromJson(account, bankCode))
          .toList();
      return accounts;
    } else {
      throw Exception('Failed to get accounts: ${response.body}');
    }
  }

  Future<Map<String, double>> getBalance(String accountId, String consentId) async {
    final token = await ensureValidToken();

    final response = await http.get(
      Uri.parse('$baseUrl/accounts/$accountId/balances'),
      headers: {
        ..._authHeaders(token),
        'x-consent-id': consentId,
        'x-requesting-bank': ApiConfig.clientId,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final balances = json['data']['balance'] as List;

      double? closingAvailable;
      double? interimAvailable;

      for (var balance in balances) {
        final type = balance['type'];
        final amount = double.tryParse(balance['amount']['amount']?.toString() ?? '0') ?? 0.0;

        if (type == 'ClosingAvailable') {
          closingAvailable = amount;
        } else if (type == 'InterimAvailable') {
          interimAvailable = amount;
        }
      }

      return {
        'balance': closingAvailable ?? interimAvailable ?? 0.0,
        'availableBalance': interimAvailable ?? closingAvailable ?? 0.0,
      };
    } else {
      throw Exception('Failed to get balance: ${response.body}');
    }
  }

  Future<List<BankTransaction>> getTransactions(
    String accountId,
    String consentId, {
    String? fromDate,
    String? toDate,
    int page = 1,
    int limit = 100,
  }) async {
    final token = await ensureValidToken();

    final queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      if (fromDate != null) 'from_booking_date_time': fromDate,
      if (toDate != null) 'to_booking_date_time': toDate,
    };

    final uri = Uri.parse('$baseUrl/accounts/$accountId/transactions')
        .replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        ..._authHeaders(token),
        'x-consent-id': consentId,
        'x-requesting-bank': ApiConfig.clientId,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final transactions = (json['data']['transaction'] as List)
          .map((tx) => BankTransaction.fromJson(tx))
          .toList();
      return transactions;
    } else {
      throw Exception('Failed to get transactions: ${response.body}');
    }
  }

  // Products
  Future<List<BankProduct>> getProducts({String? productType}) async {
    final queryParams = productType != null ? {'product_type': productType} : null;
    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: queryParams);

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final products = (json['data']['product'] as List)
          .map((product) => BankProduct.fromJson(product, bankCode))
          .toList();
      return products;
    } else {
      throw Exception('Failed to get products: ${response.body}');
    }
  }

  Future<BankProduct> getProduct(String productId) async {
    final response = await http.get(Uri.parse('$baseUrl/products/$productId'));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return BankProduct.fromJson(json['data'], bankCode);
    } else {
      throw Exception('Failed to get product: ${response.body}');
    }
  }

  // Product Agreements
  Future<Map<String, dynamic>> openProductAgreement({
    required String clientId,
    required String productId,
    required double amount,
    int? termMonths,
    String? sourceAccountId,
    required String consentId,
  }) async {
    final token = await ensureValidToken();

    final body = {
      'product_id': productId,
      'amount': amount,
      if (termMonths != null) 'term_months': termMonths,
      if (sourceAccountId != null) 'source_account_id': sourceAccountId,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/product-agreements?client_id=$clientId'),
      headers: {
        ..._authHeaders(token),
        'x-product-agreement-consent-id': consentId,
        'x-requesting-bank': ApiConfig.clientId,
      },
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to open product agreement: ${response.body}');
    }
  }

  // Payments
  Future<Map<String, dynamic>> createPayment({
    required String clientId,
    required String debtorAccountId,
    required String creditorAccountId,
    required double amount,
    String currency = 'RUB',
    String? creditorBankCode,
    String? paymentConsentId,
  }) async {
    final token = await ensureValidToken();

    final body = {
      'data': {
        'initiation': {
          'instructedAmount': {
            'amount': amount.toStringAsFixed(2),
            'currency': currency,
          },
          'debtorAccount': {
            'schemeName': 'RU.CBR.PAN',
            'identification': debtorAccountId,
          },
          'creditorAccount': {
            'schemeName': 'RU.CBR.PAN',
            'identification': creditorAccountId,
            if (creditorBankCode != null) 'bank_code': creditorBankCode,
          },
        },
      },
    };

    final headers = {
      ..._authHeaders(token),
      'x-requesting-bank': ApiConfig.clientId,
      if (paymentConsentId != null) 'x-payment-consent-id': paymentConsentId,
    };

    final response = await http.post(
      Uri.parse('$baseUrl/payments?client_id=$clientId'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create payment: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> getPaymentStatus(String paymentId) async {
    final token = await ensureValidToken();

    final response = await http.get(
      Uri.parse('$baseUrl/payments/$paymentId'),
      headers: _authHeaders(token),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to get payment status: ${response.body}');
    }
  }
}
