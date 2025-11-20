import 'dart:convert';
import 'dart:io';
import 'dart:async';
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

  // Helper to check if status is approved/active
  bool _isStatusApproved(String? status) {
    return status == 'approved' || status == 'active' || status == 'Authorized';
  }

  // Helper method for executing HTTP requests with retry mechanism
  Future<T> _executeWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 2),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (attempt < maxRetries) {
      try {
        print('[$bankCode] Attempt ${attempt + 1}/$maxRetries');
        return await operation().timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException('Превышено время ожидания ответа от $bankCode');
          },
        );
      } on SocketException catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          print('[$bankCode] Не удалось подключиться после $maxRetries попыток');
          throw Exception('Не удалось подключиться к $bankCode: ${e.message}. Проверьте подключение к интернету.');
        }
        print('[$bankCode] Ошибка сокета: ${e.message}. Повтор через ${delay.inSeconds}с...');
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      } on TimeoutException catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          print('[$bankCode] Превышено время ожидания после $maxRetries попыток');
          throw Exception('Превышено время ожидания ответа от $bankCode: ${e.message}');
        }
        print('[$bankCode] Тайм-аут: ${e.message}. Повтор через ${delay.inSeconds}с...');
        await Future.delayed(delay);
        delay *= 2;
      } on HttpException catch (e) {
        attempt++;
        if (attempt >= maxRetries) {
          print('[$bankCode] Ошибка HTTP после $maxRetries попыток');
          throw Exception('Ошибка HTTP для $bankCode: ${e.message}');
        }
        print('[$bankCode] HTTP ошибка: ${e.message}. Повтор через ${delay.inSeconds}с...');
        await Future.delayed(delay);
        delay *= 2;
      } catch (e) {
        // For other errors, don't retry
        print('[$bankCode] Неожиданная ошибка: $e');
        rethrow;
      }
    }

    throw Exception('Не удалось выполнить операцию для $bankCode после $maxRetries попыток');
  }

  // Authentication
  Future<BankToken> getBankToken() async {
    return await _executeWithRetry(() async {
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
    });
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
      'requesting_bank_name': 'Multi-Bank App',
    };

    print('[$bankCode] Creating account consent for client: $clientId');
    print('[$bankCode] Request URL: $baseUrl/account-consents/request');
    print('[$bankCode] Request body: ${jsonEncode(body)}');

    return await _executeWithRetry(() async {
      final response = await http.post(
        Uri.parse('$baseUrl/account-consents/request'),
        headers: {
          ..._authHeaders(token),
          'x-requesting-bank': ApiConfig.clientId,
        },
        body: jsonEncode(body),
      );

      print('[$bankCode] Response status: ${response.statusCode}');
      print('[$bankCode] Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);
          print('[$bankCode] Parsing JSON response, top-level keys: ${json.keys.toList()}');

          // Try to extract consent ID from various possible locations
          // Priority: consent_id (underscore) > consentId (camelCase) > data.consent_id > data.consentId
          String consentId = '';
          String status = 'pending';
          String createdAt = DateTime.now().toIso8601String();

          // Check if response has 'data' field (nested structure)
          if (json is Map && json.containsKey('data') && json['data'] != null) {
            print('[$bankCode] Response has "data" wrapper (nested structure)');
            final data = json['data'];

            // Try consent_id first, then consentId, then request_id (for SBank)
            consentId = data['consent_id'] ?? data['consentId'] ?? data['request_id'] ?? '';
            status = data['status'] ?? 'pending';
            createdAt = data['creationDateTime'] ?? data['creation_date_time'] ?? data['created_at'] ?? DateTime.now().toIso8601String();

            print('[$bankCode] Extracted from data: consent_id="$consentId", status="$status"');
          } else {
            // Flat structure (no 'data' wrapper) - this is what SBank uses
            print('[$bankCode] Flat response structure (no "data" wrapper) - SBank format');

            // Try consent_id first, then consentId, then request_id (for SBank)
            // SBank specifically returns "request_id" instead of "consent_id"
            consentId = json['consent_id'] ?? json['consentId'] ?? json['request_id'] ?? '';
            status = json['status'] ?? 'pending';
            createdAt = json['creationDateTime'] ?? json['creation_date_time'] ?? json['created_at'] ?? DateTime.now().toIso8601String();

            print('[$bankCode] Extracted directly: consent_id="$consentId", status="$status"');
            if (json['request_id'] != null) {
              print('[$bankCode] NOTE: Using request_id from SBank: "$consentId"');
            }
          }

          if (consentId.isEmpty) {
            print('[$bankCode] ERROR: Consent ID is empty! Full response: ${response.body}');
            throw Exception('Failed to extract consent_id from response. Keys available: ${json.keys.toList()}');
          }

          // Convert to our internal format
          final consentData = {
            'consent_id': consentId,
            'status': status,
            'created_at': createdAt,
            'auto_approved': _isStatusApproved(status),
          };

          print('[$bankCode] Final consent data: $consentData');
          return AccountConsent.fromJson(consentData, bankCode);
        } catch (e) {
          throw Exception('Failed to parse account consent response from $bankCode. Response: ${response.body}. Error: $e');
        }
      } else {
        throw Exception('Failed to create account consent for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
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
      try {
        final json = jsonDecode(response.body);

        // Try to extract from various possible locations (prioritize underscore format)
        String consentId = '';
        String status = 'pending';
        String consentType = 'vrp';

        if (json is Map && json.containsKey('data') && json['data'] != null) {
          final data = json['data'];
          consentId = data['consent_id'] ?? data['consentId'] ?? data['request_id'] ?? '';
          status = data['status'] ?? 'pending';
          consentType = data['consent_type'] ?? data['consentType'] ?? 'vrp';
        } else {
          // Flat structure - prioritize underscore format, also check request_id for SBank
          consentId = json['consent_id'] ?? json['consentId'] ?? json['request_id'] ?? '';
          status = json['status'] ?? 'pending';
          consentType = json['consent_type'] ?? json['consentType'] ?? 'vrp';
        }

        if (consentId.isEmpty) {
          print('[$bankCode] ERROR: Payment consent ID is empty! Response: ${response.body}');
        }

        final consentData = {
          'consent_id': consentId,
          'status': status,
          'consent_type': consentType,
          'auto_approved': _isStatusApproved(status),
        };

        return PaymentConsent.fromJson(consentData, bankCode);
      } catch (e) {
        throw Exception('Failed to parse payment consent response from $bankCode. Response: ${response.body}. Error: $e');
      }
    } else {
      throw Exception('Failed to create payment consent for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
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
      try {
        final json = jsonDecode(response.body);

        // Try to extract from various possible locations (prioritize underscore format)
        String consentId = '';
        String status = 'pending';

        if (json is Map && json.containsKey('data') && json['data'] != null) {
          final data = json['data'];
          consentId = data['consent_id'] ?? data['consentId'] ?? data['request_id'] ?? '';
          status = data['status'] ?? 'pending';
        } else {
          // Flat structure - prioritize underscore format, also check request_id for SBank
          consentId = json['consent_id'] ?? json['consentId'] ?? json['request_id'] ?? '';
          status = json['status'] ?? 'pending';
        }

        if (consentId.isEmpty) {
          print('[$bankCode] ERROR: Product consent ID is empty! Response: ${response.body}');
        }

        final consentData = {
          'consent_id': consentId,
          'status': status,
          'auto_approved': _isStatusApproved(status),
        };

        return ProductAgreementConsent.fromJson(consentData, bankCode);
      } catch (e) {
        throw Exception('Failed to parse product consent response from $bankCode. Response: ${response.body}. Error: $e');
      }
    } else {
      throw Exception('Failed to create product agreement consent for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
    }
  }

  // Get consent status from bank
  Future<AccountConsent> getAccountConsentStatus(String consentId, String clientId) async {
    print('[$bankCode] Checking account consent status for ID: "$consentId"');
    print('[$bankCode] Client ID for header: "$clientId"');

    // Validate consent ID is not empty
    if (consentId.isEmpty) {
      throw Exception('[$bankCode] Cannot check consent status: consent ID is empty!');
    }

    // Ensure we have a valid token
    final token = await ensureValidToken();

    // Extract base team ID from client ID (e.g., "team201-10" -> "team201")
    final baseTeamId = clientId.contains('-') ? clientId.split('-')[0] : clientId;
    print('[$bankCode] Base team ID for x-fapi-interaction-id: "$baseTeamId"');

    final url = '$baseUrl/account-consents/$consentId';
    print('[$bankCode] Request URL: $url');

    return await _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'accept': 'application/json',
          'x-fapi-interaction-id': baseTeamId,
        },
      );

      print('[$bankCode] Request headers: {Authorization: Bearer <token>, accept: application/json, x-fapi-interaction-id: $baseTeamId}');
      print('[$bankCode] Status check response code: ${response.statusCode}');
      print('[$bankCode] Status check response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);

          // Check if response has 'data' field
          if (json is Map && json.containsKey('data') && json['data'] != null) {
            final data = json['data'];

            // Convert API response format to our internal format
            // Extract the NEW consent_id from the response (may change when approved)
            final newConsentId = data['consentId'] ?? data['consent_id'] ?? data['request_id'] ?? consentId;
            final consentData = {
              'consent_id': newConsentId,
              'status': data['status'] ?? 'pending',
              'created_at': data['creationDateTime'] ?? data['creation_date_time'] ?? data['created_at'] ?? DateTime.now().toIso8601String(),
              'auto_approved': _isStatusApproved(data['status']),
            };

            print('[$bankCode] Parsed consent - ID: $newConsentId, Status: ${consentData["status"]}, Approved: ${consentData["auto_approved"]}');
            return AccountConsent.fromJson(consentData, bankCode);
          } else {
            // If no 'data' field, try to parse directly
            // Extract the NEW consent_id from the response (may change when approved)
            final newConsentId = json['consentId'] ?? json['consent_id'] ?? json['request_id'] ?? consentId;
            final consentData = {
              'consent_id': newConsentId,
              'status': json['status'] ?? 'pending',
              'created_at': json['creationDateTime'] ?? json['creation_date_time'] ?? json['created_at'] ?? DateTime.now().toIso8601String(),
              'auto_approved': _isStatusApproved(json['status']),
            };

            print('[$bankCode] Parsed consent (direct) - ID: $newConsentId, Status: ${consentData["status"]}, Approved: ${consentData["auto_approved"]}');
            return AccountConsent.fromJson(consentData, bankCode);
          }
        } catch (e) {
          print('[$bankCode] Error parsing consent status response: $e');
          throw Exception('Failed to parse account consent status from $bankCode. Response: ${response.body}. Error: $e');
        }
      } else {
        print('[$bankCode] Failed to get consent status. Status code: ${response.statusCode}');
        throw Exception('Failed to get account consent status for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<PaymentConsent> getPaymentConsentStatus(String consentId, String clientId) async {
    print('[$bankCode] Checking payment consent status for ID: $consentId');
    print('[$bankCode] Client ID for header: "$clientId"');

    // Ensure we have a valid token
    final token = await ensureValidToken();

    // Extract base team ID from client ID (e.g., "team201-10" -> "team201")
    final baseTeamId = clientId.contains('-') ? clientId.split('-')[0] : clientId;
    print('[$bankCode] Base team ID for x-fapi-interaction-id: "$baseTeamId"');

    return await _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse('$baseUrl/payment-consents/$consentId'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'accept': 'application/json',
          'x-fapi-interaction-id': baseTeamId,
        },
      );

      print('[$bankCode] Payment status check response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);

          // Check if response has 'data' field
          if (json is Map && json.containsKey('data') && json['data'] != null) {
            final data = json['data'];

            // Convert API response format to our internal format
            // Also check for request_id (SBank uses this)
            final consentData = {
              'consent_id': data['consentId'] ?? data['consent_id'] ?? data['request_id'] ?? consentId,
              'status': data['status'] ?? 'pending',
              'consent_type': data['consentType'] ?? data['consent_type'] ?? 'vrp',
              'auto_approved': _isStatusApproved(data['status']),
            };

            return PaymentConsent.fromJson(consentData, bankCode);
          } else {
            // If no 'data' field, try to parse directly
            // Also check for request_id (SBank uses this)
            final consentData = {
              'consent_id': json['consentId'] ?? json['consent_id'] ?? json['request_id'] ?? consentId,
              'status': json['status'] ?? 'pending',
              'consent_type': json['consentType'] ?? json['consent_type'] ?? 'vrp',
              'auto_approved': _isStatusApproved(json['status']),
            };

            return PaymentConsent.fromJson(consentData, bankCode);
          }
        } catch (e) {
          throw Exception('Failed to parse payment consent status from $bankCode. Response: ${response.body}. Error: $e');
        }
      } else {
        throw Exception('Failed to get payment consent status for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<ProductAgreementConsent> getProductConsentStatus(String consentId, String clientId) async {
    print('[$bankCode] Checking product consent status for ID: $consentId');
    print('[$bankCode] Client ID for header: "$clientId"');

    // Ensure we have a valid token
    final token = await ensureValidToken();

    // Extract base team ID from client ID (e.g., "team201-10" -> "team201")
    final baseTeamId = clientId.contains('-') ? clientId.split('-')[0] : clientId;
    print('[$bankCode] Base team ID for x-fapi-interaction-id: "$baseTeamId"');

    return await _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse('$baseUrl/product-agreement-consents/$consentId'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'accept': 'application/json',
          'x-fapi-interaction-id': baseTeamId,
        },
      );

      print('[$bankCode] Product status check response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final json = jsonDecode(response.body);

          // Check if response has 'data' field
          if (json is Map && json.containsKey('data') && json['data'] != null) {
            final data = json['data'];

            // Convert API response format to our internal format
            // Also check for request_id (SBank uses this)
            final consentData = {
              'consent_id': data['consentId'] ?? data['consent_id'] ?? data['request_id'] ?? consentId,
              'status': data['status'] ?? 'pending',
              'auto_approved': _isStatusApproved(data['status']),
            };

            return ProductAgreementConsent.fromJson(consentData, bankCode);
          } else {
            // If no 'data' field, try to parse directly
            // Also check for request_id (SBank uses this)
            final consentData = {
              'consent_id': json['consentId'] ?? json['consent_id'] ?? json['request_id'] ?? consentId,
              'status': json['status'] ?? 'pending',
              'auto_approved': _isStatusApproved(json['status']),
            };

            return ProductAgreementConsent.fromJson(consentData, bankCode);
          }
        } catch (e) {
          throw Exception('Failed to parse product consent status from $bankCode. Response: ${response.body}. Error: $e');
        }
      } else {
        throw Exception('Failed to get product consent status for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  // Consent Revocation (GDPR requirement)
  Future<bool> deleteAccountConsent(String consentId, String clientId) async {
    print('[$bankCode] Revoking account consent: $consentId');

    final token = await ensureValidToken();
    final baseTeamId = clientId.contains('-') ? clientId.split('-')[0] : clientId;

    return await _executeWithRetry(() async {
      final response = await http.delete(
        Uri.parse('$baseUrl/account-consents/$consentId'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'accept': 'application/json',
          'x-fapi-interaction-id': baseTeamId,
          'x-requesting-bank': ApiConfig.clientId,
        },
      );

      print('[$bankCode] Delete account consent response code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('[$bankCode] Account consent successfully revoked');
        return true;
      } else {
        throw Exception('Failed to revoke account consent for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<bool> deletePaymentConsent(String consentId, String clientId) async {
    print('[$bankCode] Revoking payment consent: $consentId');

    final token = await ensureValidToken();
    final baseTeamId = clientId.contains('-') ? clientId.split('-')[0] : clientId;

    return await _executeWithRetry(() async {
      final response = await http.delete(
        Uri.parse('$baseUrl/payment-consents/$consentId'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'accept': 'application/json',
          'x-fapi-interaction-id': baseTeamId,
          'x-requesting-bank': ApiConfig.clientId,
        },
      );

      print('[$bankCode] Delete payment consent response code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('[$bankCode] Payment consent successfully revoked');
        return true;
      } else {
        throw Exception('Failed to revoke payment consent for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<bool> deleteProductAgreementConsent(String consentId, String clientId) async {
    print('[$bankCode] Revoking product agreement consent: $consentId');

    final token = await ensureValidToken();
    final baseTeamId = clientId.contains('-') ? clientId.split('-')[0] : clientId;

    return await _executeWithRetry(() async {
      final response = await http.delete(
        Uri.parse('$baseUrl/product-agreement-consents/$consentId'),
        headers: {
          'Authorization': 'Bearer ${token.accessToken}',
          'accept': 'application/json',
          'x-fapi-interaction-id': baseTeamId,
          'x-requesting-bank': ApiConfig.clientId,
        },
      );

      print('[$bankCode] Delete product consent response code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('[$bankCode] Product agreement consent successfully revoked');
        return true;
      } else {
        throw Exception('Failed to revoke product agreement consent for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
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

  // Account Management
  Future<Map<String, dynamic>> createAccount({
    required String clientId,
    required String accountType,
    required String currency,
    String? accountName,
    String? consentId,
  }) async {
    print('[$bankCode] Creating new account for client: $clientId');

    final token = await ensureValidToken();

    final body = {
      'account_type': accountType,
      'currency': currency,
      if (accountName != null) 'account_name': accountName,
    };

    return await _executeWithRetry(() async {
      final response = await http.post(
        Uri.parse('$baseUrl/accounts?client_id=$clientId'),
        headers: {
          ..._authHeaders(token),
          if (consentId != null) 'x-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
        body: jsonEncode(body),
      );

      print('[$bankCode] Create account response code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[$bankCode] Account successfully created');
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to create account for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<Map<String, dynamic>> closeAccount({
    required String accountId,
    required String clientId,
    String? transferToAccountId,
    bool donateToBank = false,
    String? consentId,
  }) async {
    print('[$bankCode] Closing account: $accountId');

    final token = await ensureValidToken();

    final body = {
      if (transferToAccountId != null) 'transfer_to_account_id': transferToAccountId,
      'donate_to_bank': donateToBank,
    };

    return await _executeWithRetry(() async {
      final response = await http.put(
        Uri.parse('$baseUrl/accounts/$accountId/close?client_id=$clientId'),
        headers: {
          ..._authHeaders(token),
          if (consentId != null) 'x-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
        body: jsonEncode(body),
      );

      print('[$bankCode] Close account response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[$bankCode] Account successfully closed');
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to close account for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<Map<String, dynamic>> updateAccountStatus({
    required String accountId,
    required String clientId,
    required String status,
    String? consentId,
  }) async {
    print('[$bankCode] Updating account status: $accountId to $status');

    final token = await ensureValidToken();

    final body = {
      'status': status,
    };

    return await _executeWithRetry(() async {
      final response = await http.put(
        Uri.parse('$baseUrl/accounts/$accountId/status?client_id=$clientId'),
        headers: {
          ..._authHeaders(token),
          if (consentId != null) 'x-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
        body: jsonEncode(body),
      );

      print('[$bankCode] Update account status response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[$bankCode] Account status successfully updated');
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update account status for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  // Products
  Future<List<BankProduct>> getProducts({String? productType}) async {
    final token = await ensureValidToken();

    final queryParams = productType != null ? {'product_type': productType} : null;
    final uri = Uri.parse('$baseUrl/products').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        ..._authHeaders(token),
        'x-requesting-bank': ApiConfig.clientId,
      },
    );

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
    final token = await ensureValidToken();

    final response = await http.get(
      Uri.parse('$baseUrl/products/$productId'),
      headers: {
        ..._authHeaders(token),
        'x-requesting-bank': ApiConfig.clientId,
      },
    );

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

  Future<List<Map<String, dynamic>>> getProductAgreements({
    required String clientId,
    required String consentId,
    String? productType,
    String? status,
  }) async {
    print('[$bankCode] Getting product agreements for client: $clientId');

    final token = await ensureValidToken();

    final queryParams = {
      'client_id': clientId,
      if (productType != null) 'product_type': productType,
      if (status != null) 'status': status,
    };

    final uri = Uri.parse('$baseUrl/product-agreements')
        .replace(queryParameters: queryParams);

    return await _executeWithRetry(() async {
      final response = await http.get(
        uri,
        headers: {
          ..._authHeaders(token),
          'x-product-agreement-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
      );

      print('[$bankCode] Get product agreements response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final agreements = (json['data']['agreements'] ?? json['data']['product_agreements'] ?? []) as List;
        print('[$bankCode] Found ${agreements.length} product agreements');
        return agreements.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get product agreements for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<Map<String, dynamic>> getProductAgreement({
    required String agreementId,
    required String clientId,
    required String consentId,
  }) async {
    print('[$bankCode] Getting product agreement: $agreementId');

    final token = await ensureValidToken();

    return await _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse('$baseUrl/product-agreements/$agreementId?client_id=$clientId'),
        headers: {
          ..._authHeaders(token),
          'x-product-agreement-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
      );

      print('[$bankCode] Get product agreement response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['data'] ?? json;
      } else {
        throw Exception('Failed to get product agreement for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<Map<String, dynamic>> closeProductAgreement({
    required String agreementId,
    required String clientId,
    required String consentId,
    bool earlyTermination = false,
  }) async {
    print('[$bankCode] Closing product agreement: $agreementId');

    final token = await ensureValidToken();

    return await _executeWithRetry(() async {
      final response = await http.delete(
        Uri.parse('$baseUrl/product-agreements/$agreementId?client_id=$clientId&early_termination=$earlyTermination'),
        headers: {
          ..._authHeaders(token),
          'x-product-agreement-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
      );

      print('[$bankCode] Close product agreement response code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('[$bankCode] Product agreement successfully closed');
        return response.statusCode == 200 ? jsonDecode(response.body) : {'status': 'closed'};
      } else {
        throw Exception('Failed to close product agreement for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
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
    String? comment,
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
          if (comment != null && comment.isNotEmpty) 'comment': comment,
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

  // Card Management
  Future<List<Map<String, dynamic>>> getCards({
    required String clientId,
    required String consentId,
  }) async {
    print('[$bankCode] Getting cards for client: $clientId');

    final token = await ensureValidToken();

    return await _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse('$baseUrl/cards?client_id=$clientId'),
        headers: {
          ..._authHeaders(token),
          'x-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
      );

      print('[$bankCode] Get cards response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final cards = (json['data']['cards'] ?? json['data']['card'] ?? []) as List;
        print('[$bankCode] Found ${cards.length} cards');
        return cards.cast<Map<String, dynamic>>();
      } else {
        throw Exception('Failed to get cards for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<Map<String, dynamic>> issueCard({
    required String clientId,
    required String accountId,
    required String cardType,
    required String consentId,
    String? cardName,
    Map<String, double>? limits,
  }) async {
    print('[$bankCode] Issuing new card for client: $clientId');

    final token = await ensureValidToken();

    final body = {
      'account_id': accountId,
      'card_type': cardType,
      if (cardName != null) 'card_name': cardName,
      if (limits != null) 'limits': limits,
    };

    return await _executeWithRetry(() async {
      final response = await http.post(
        Uri.parse('$baseUrl/cards?client_id=$clientId'),
        headers: {
          ..._authHeaders(token),
          'x-product-agreement-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
        body: jsonEncode(body),
      );

      print('[$bankCode] Issue card response code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('[$bankCode] Card successfully issued');
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to issue card for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<Map<String, dynamic>> getCard({
    required String cardId,
    required String clientId,
    required String consentId,
  }) async {
    print('[$bankCode] Getting card details: $cardId');

    final token = await ensureValidToken();

    return await _executeWithRetry(() async {
      final response = await http.get(
        Uri.parse('$baseUrl/cards/$cardId?client_id=$clientId'),
        headers: {
          ..._authHeaders(token),
          'x-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
      );

      print('[$bankCode] Get card response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['data'] ?? json;
      } else {
        throw Exception('Failed to get card for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<Map<String, dynamic>> deleteCard({
    required String cardId,
    required String clientId,
    required String consentId,
    bool reissue = false,
  }) async {
    print('[$bankCode] Deleting card: $cardId (reissue: $reissue)');

    final token = await ensureValidToken();

    return await _executeWithRetry(() async {
      final response = await http.delete(
        Uri.parse('$baseUrl/cards/$cardId?client_id=$clientId&reissue=$reissue'),
        headers: {
          ..._authHeaders(token),
          'x-product-agreement-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
      );

      print('[$bankCode] Delete card response code: ${response.statusCode}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('[$bankCode] Card successfully deleted');
        return response.statusCode == 200 ? jsonDecode(response.body) : {'status': 'deleted'};
      } else {
        throw Exception('Failed to delete card for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<Map<String, dynamic>> updateCardLimits({
    required String cardId,
    required String clientId,
    required String consentId,
    required Map<String, double> limits,
  }) async {
    print('[$bankCode] Updating card limits: $cardId');

    final token = await ensureValidToken();

    final body = {
      'limits': limits,
    };

    return await _executeWithRetry(() async {
      final response = await http.put(
        Uri.parse('$baseUrl/cards/$cardId/limits?client_id=$clientId'),
        headers: {
          ..._authHeaders(token),
          'x-product-agreement-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
        body: jsonEncode(body),
      );

      print('[$bankCode] Update card limits response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[$bankCode] Card limits successfully updated');
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update card limits for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }

  Future<Map<String, dynamic>> updateCardStatus({
    required String cardId,
    required String clientId,
    required String consentId,
    required String status,
    String? reason,
  }) async {
    print('[$bankCode] Updating card status: $cardId to $status');

    final token = await ensureValidToken();

    final body = {
      'status': status,
      if (reason != null) 'reason': reason,
    };

    return await _executeWithRetry(() async {
      final response = await http.put(
        Uri.parse('$baseUrl/cards/$cardId/status?client_id=$clientId'),
        headers: {
          ..._authHeaders(token),
          'x-product-agreement-consent-id': consentId,
          'x-requesting-bank': ApiConfig.clientId,
        },
        body: jsonEncode(body),
      );

      print('[$bankCode] Update card status response code: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('[$bankCode] Card status successfully updated');
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to update card status for $bankCode. Status: ${response.statusCode}. Body: ${response.body}');
      }
    });
  }
}
