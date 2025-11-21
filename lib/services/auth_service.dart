import 'dart:convert';
import '../models/bank_token.dart';
import '../models/consent.dart';
import 'bank_api_service.dart';
import 'secure_storage_service.dart';

class AuthService {
  final _secureStorage = SecureStorageService();

  final Map<String, BankApiService> _bankServices = {};
  final Map<String, BankToken> _tokens = {};
  final Map<String, AccountConsent> _accountConsents = {};
  final Map<String, PaymentConsent> _paymentConsents = {};
  final Map<String, ProductAgreementConsent> _productConsents = {};

  String? _clientId;

  AuthService() {
    _initializeBankServices();
  }

  void _initializeBankServices() {
    _bankServices['vbank'] = BankApiService('vbank');
    _bankServices['abank'] = BankApiService('abank');
    _bankServices['sbank'] = BankApiService('sbank');
    _bankServices['babank'] = BankApiService('babank');
  }

  BankApiService getBankService(String bankCode) {
    return _bankServices[bankCode]!;
  }

  // Client ID Management
  Future<void> setClientId(String clientId) async {
    _clientId = clientId;
    await _secureStorage.saveClientId(clientId);
  }

  Future<String?> getClientId() async {
    if (_clientId != null) return _clientId;

    _clientId = await _secureStorage.readClientId();
    return _clientId;
  }

  String get clientId => _clientId ?? '';

  // Token Management
  Future<void> loadTokens() async {
    final tokensJson = await _secureStorage.readTokens();

    if (tokensJson != null) {
      final tokensData = jsonDecode(tokensJson) as Map<String, dynamic>;
      _tokens.clear();
      tokensData.forEach((bankCode, tokenJson) {
        _tokens[bankCode] = BankToken.fromJson(tokenJson, bankCode);
      });
    }
  }

  Future<void> saveTokens() async {
    final tokensData = <String, dynamic>{};
    _tokens.forEach((bankCode, token) {
      tokensData[bankCode] = token.toJson();
    });
    await _secureStorage.saveTokens(jsonEncode(tokensData));
  }

  Future<BankToken> getTokenForBank(String bankCode) async {
    // Check if we have a valid token
    if (_tokens.containsKey(bankCode) && !_tokens[bankCode]!.isExpired) {
      return _tokens[bankCode]!;
    }

    // Get new token
    final service = getBankService(bankCode);
    final token = await service.getBankToken();
    _tokens[bankCode] = token;
    await saveTokens();
    return token;
  }

  // Consent Management
  Future<void> loadConsents() async {
    // Account consents
    final accountConsentsJson = await _secureStorage.readAccountConsents();
    if (accountConsentsJson != null) {
      final consentsData = jsonDecode(accountConsentsJson) as Map<String, dynamic>;
      _accountConsents.clear();
      consentsData.forEach((bankCode, consentJson) {
        _accountConsents[bankCode] = AccountConsent.fromJson(consentJson, bankCode);
      });
    }

    // Payment consents
    final paymentConsentsJson = await _secureStorage.readPaymentConsents();
    if (paymentConsentsJson != null) {
      final consentsData = jsonDecode(paymentConsentsJson) as Map<String, dynamic>;
      _paymentConsents.clear();
      consentsData.forEach((bankCode, consentJson) {
        _paymentConsents[bankCode] = PaymentConsent.fromJson(consentJson, bankCode);
      });
    }

    // Product consents
    final productConsentsJson = await _secureStorage.readProductConsents();
    if (productConsentsJson != null) {
      final consentsData = jsonDecode(productConsentsJson) as Map<String, dynamic>;
      _productConsents.clear();
      consentsData.forEach((bankCode, consentJson) {
        _productConsents[bankCode] = ProductAgreementConsent.fromJson(consentJson, bankCode);
      });
    }
  }

  Future<void> saveConsents() async {
    // Save account consents
    final accountConsentsData = <String, dynamic>{};
    _accountConsents.forEach((bankCode, consent) {
      accountConsentsData[bankCode] = consent.toJson();
    });
    await _secureStorage.saveAccountConsents(jsonEncode(accountConsentsData));

    // Save payment consents
    final paymentConsentsData = <String, dynamic>{};
    _paymentConsents.forEach((bankCode, consent) {
      paymentConsentsData[bankCode] = consent.toJson();
    });
    await _secureStorage.savePaymentConsents(jsonEncode(paymentConsentsData));

    // Save product consents
    final productConsentsData = <String, dynamic>{};
    _productConsents.forEach((bankCode, consent) {
      productConsentsData[bankCode] = consent.toJson();
    });
    await _secureStorage.saveProductConsents(jsonEncode(productConsentsData));
  }

  Future<AccountConsent> getAccountConsent(String bankCode) async {
    // Check if we have any existing consent (approved OR pending)
    if (_accountConsents.containsKey(bankCode)) {
      final existingConsent = _accountConsents[bankCode]!;
      // Return existing consent whether it's approved or pending
      // This prevents duplicate consent creation
      print('[AuthService] Returning existing consent for $bankCode - ID: ${existingConsent.consentId}, Status: ${existingConsent.status}, Approved: ${existingConsent.isApproved}');
      return existingConsent;
    }

    // Create new consent only if none exists
    try {
      print('[AuthService] No existing consent found for $bankCode, creating new one');
      final service = getBankService(bankCode);
      final consent = await service.createAccountConsent(clientId);
      _accountConsents[bankCode] = consent;
      await saveConsents();
      print('[AuthService] Created consent for $bankCode - ID: ${consent.consentId}, Status: ${consent.status}');
      return consent;
    } catch (e) {
      // If consent creation fails, throw with more context
      throw Exception('Failed to create account consent for $bankCode: $e');
    }
  }

  Future<void> recreateAccountConsent(String bankCode) async {
    try {
      final service = getBankService(bankCode);
      final consent = await service.createAccountConsent(clientId);
      _accountConsents[bankCode] = consent;
      await saveConsents();
    } catch (e) {
      throw Exception('Failed to recreate account consent for $bankCode: $e');
    }
  }

  Future<PaymentConsent> getPaymentConsent(String bankCode, String debtorAccount) async {
    // Check if we have any existing consent (approved OR pending)
    if (_paymentConsents.containsKey(bankCode)) {
      final existingConsent = _paymentConsents[bankCode]!;
      print('[AuthService] Returning existing payment consent for $bankCode: ${existingConsent.status}');
      return existingConsent;
    }

    // Create new consent only if none exists
    try {
      print('[AuthService] Creating new payment consent for $bankCode');
      final service = getBankService(bankCode);
      final consent = await service.createPaymentConsent(clientId, debtorAccount);
      _paymentConsents[bankCode] = consent;
      await saveConsents();
      return consent;
    } catch (e) {
      throw Exception('Failed to create payment consent for $bankCode: $e');
    }
  }

  Future<void> recreatePaymentConsent(String bankCode, String debtorAccount) async {
    try {
      final service = getBankService(bankCode);
      final consent = await service.createPaymentConsent(clientId, debtorAccount);
      _paymentConsents[bankCode] = consent;
      await saveConsents();
    } catch (e) {
      throw Exception('Failed to recreate payment consent for $bankCode: $e');
    }
  }

  Future<ProductAgreementConsent> getProductConsent(String bankCode) async {
    // Check if we have any existing consent (approved OR pending)
    if (_productConsents.containsKey(bankCode)) {
      final existingConsent = _productConsents[bankCode]!;
      print('[AuthService] Returning existing product consent for $bankCode: ${existingConsent.status}');
      return existingConsent;
    }

    // Create new consent only if none exists
    try {
      print('[AuthService] Creating new product consent for $bankCode');
      final service = getBankService(bankCode);
      final consent = await service.createProductAgreementConsent(clientId);
      _productConsents[bankCode] = consent;
      await saveConsents();
      return consent;
    } catch (e) {
      throw Exception('Failed to create product consent for $bankCode: $e');
    }
  }

  Future<void> recreateProductConsent(String bankCode) async {
    try {
      final service = getBankService(bankCode);
      final consent = await service.createProductAgreementConsent(clientId);
      _productConsents[bankCode] = consent;
      await saveConsents();
    } catch (e) {
      throw Exception('Failed to recreate product consent for $bankCode: $e');
    }
  }

  /// Create all consents for all banks
  Future<Map<String, bool>> createAllConsents() async {
    final results = <String, bool>{};

    for (final bankCode in supportedBanks) {
      try {
        // Create account consent
        await recreateAccountConsent(bankCode);

        // Create payment consent (using empty debtorAccount for now)
        try {
          await recreatePaymentConsent(bankCode, '');
        } catch (e) {
          // Payment consent might fail without valid account, continue
        }

        // Create product consent
        try {
          await recreateProductConsent(bankCode);
        } catch (e) {
          // Product consent might fail, continue
        }

        results[bankCode] = true;
      } catch (e) {
        results[bankCode] = false;
      }
    }

    return results;
  }

  /// Get consent status for a bank
  Map<String, dynamic> getConsentStatus(String bankCode) {
    return {
      'account_consent': _accountConsents[bankCode]?.toJson(),
      'payment_consent': _paymentConsents[bankCode]?.toJson(),
      'product_consent': _productConsents[bankCode]?.toJson(),
    };
  }

  /// Check if bank has all required consents
  bool hasRequiredConsents(String bankCode) {
    final hasConsent = _accountConsents.containsKey(bankCode);
    final isApproved = hasConsent && _accountConsents[bankCode]!.isApproved;

    print('[AuthService] hasRequiredConsents($bankCode): hasConsent=$hasConsent, isApproved=$isApproved');
    if (hasConsent) {
      print('[AuthService] Consent status for $bankCode: ${_accountConsents[bankCode]!.status}');
    }

    return hasConsent && isApproved;
  }

  /// Auto-create missing consents for all banks
  Future<Map<String, bool>> autoCreateMissingConsents() async {
    final results = <String, bool>{};

    for (final bankCode in supportedBanks) {
      // Check if account consent exists (even if pending)
      final hasAccountConsent = _accountConsents.containsKey(bankCode);

      if (!hasAccountConsent) {
        // Only create consent if it doesn't exist at all
        print('[AuthService] Creating missing consent for $bankCode');
        try {
          // Create account consent
          await recreateAccountConsent(bankCode);

          // Try to create payment consent with empty debtor account (VRP)
          try {
            await recreatePaymentConsent(bankCode, '');
          } catch (e) {
            // Payment consent creation failed, but continue
            print('[AuthService] Failed to create payment consent for $bankCode: $e');
          }

          // Try to create product consent (optional, don't fail if it doesn't work)
          try {
            await recreateProductConsent(bankCode);
          } catch (e) {
            // Product consent creation failed, but continue
            print('[AuthService] Failed to create product consent for $bankCode: $e');
          }

          results[bankCode] = true;
        } catch (e) {
          print('[AuthService] Failed to create account consent for $bankCode: $e');
          results[bankCode] = false;
        }
      } else {
        // Consent already exists (approved or pending), don't recreate
        final status = _accountConsents[bankCode]!.status;
        print('[AuthService] Consent already exists for $bankCode with status: $status');
        results[bankCode] = true;
      }
    }

    return results;
  }

  /// Check if any consents are missing (not created at all)
  bool get hasMissingConsents {
    for (final bankCode in supportedBanks) {
      // A consent is "missing" only if it doesn't exist at all
      // Pending consents are NOT missing, they're just awaiting approval
      if (!_accountConsents.containsKey(bankCode)) {
        return true;
      }
    }
    return false;
  }

  /// Get list of banks with pending consents (account, payment, or product)
  List<String> get banksWithPendingConsents {
    final pending = <String>{};
    for (final bankCode in supportedBanks) {
      // Check account consents
      if (_accountConsents.containsKey(bankCode) &&
          _accountConsents[bankCode]!.isPending) {
        pending.add(bankCode);
      }
      // Check payment consents
      if (_paymentConsents.containsKey(bankCode) &&
          _paymentConsents[bankCode]!.isPending) {
        pending.add(bankCode);
      }
      // Check product consents
      if (_productConsents.containsKey(bankCode) &&
          _productConsents[bankCode]!.isPending) {
        pending.add(bankCode);
      }
    }
    return pending.toList();
  }

  /// Check if any consents are pending approval
  bool get hasPendingConsents {
    return banksWithPendingConsents.isNotEmpty;
  }

  /// Refresh account consent status from bank
  Future<AccountConsent?> refreshAccountConsentStatus(String bankCode) async {
    try {
      print('[AuthService] Refreshing account consent for $bankCode');

      // Check if we have a consent ID stored
      if (!_accountConsents.containsKey(bankCode)) {
        print('[AuthService] No stored consent found for $bankCode');
        return null;
      }

      // Get client ID
      final clientId = await getClientId();
      if (clientId == null || clientId.isEmpty) {
        print('[AuthService] ERROR: Client ID is not set!');
        throw Exception('Client ID is not set. Cannot check consent status.');
      }

      final storedConsent = _accountConsents[bankCode]!;
      print('[AuthService] Stored consent ID: "${storedConsent.consentId}", Status: ${storedConsent.status}');

      // Validate consent ID is not empty
      if (storedConsent.consentId.isEmpty) {
        print('[AuthService] ERROR: Consent ID is empty for $bankCode! Cannot check status.');
        throw Exception('Consent ID is empty for $bankCode. Consent may not have been created properly.');
      }

      final service = getBankService(bankCode);

      // Fetch current status from bank
      print('[AuthService] Fetching current status from $bankCode with consent ID: ${storedConsent.consentId}');
      final updatedConsent = await service.getAccountConsentStatus(storedConsent.consentId, clientId);

      print('[AuthService] Received updated status: ${updatedConsent.status}');

      // Update stored consent
      _accountConsents[bankCode] = updatedConsent;
      await saveConsents();

      print('[AuthService] Consent status updated and saved for $bankCode');

      return updatedConsent;
    } catch (e) {
      print('[AuthService] Error refreshing consent for $bankCode: $e');
      throw Exception('Failed to refresh account consent status for $bankCode: $e');
    }
  }

  /// Refresh payment consent status from bank
  Future<PaymentConsent?> refreshPaymentConsentStatus(String bankCode) async {
    try {
      // Check if we have a consent ID stored
      if (!_paymentConsents.containsKey(bankCode)) {
        return null;
      }

      // Get client ID
      final clientId = await getClientId();
      if (clientId == null || clientId.isEmpty) {
        throw Exception('Client ID is not set. Cannot check consent status.');
      }

      final storedConsent = _paymentConsents[bankCode]!;
      final service = getBankService(bankCode);

      // Fetch current status from bank
      final updatedConsent = await service.getPaymentConsentStatus(storedConsent.consentId, clientId);

      // Update stored consent
      _paymentConsents[bankCode] = updatedConsent;
      await saveConsents();

      return updatedConsent;
    } catch (e) {
      throw Exception('Failed to refresh payment consent status for $bankCode: $e');
    }
  }

  /// Refresh product consent status from bank
  Future<ProductAgreementConsent?> refreshProductConsentStatus(String bankCode) async {
    try {
      // Check if we have a consent ID stored
      if (!_productConsents.containsKey(bankCode)) {
        return null;
      }

      // Get client ID
      final clientId = await getClientId();
      if (clientId == null || clientId.isEmpty) {
        throw Exception('Client ID is not set. Cannot check consent status.');
      }

      final storedConsent = _productConsents[bankCode]!;
      final service = getBankService(bankCode);

      // Fetch current status from bank
      final updatedConsent = await service.getProductConsentStatus(storedConsent.consentId, clientId);

      // Update stored consent
      _productConsents[bankCode] = updatedConsent;
      await saveConsents();

      return updatedConsent;
    } catch (e) {
      throw Exception('Failed to refresh product consent status for $bankCode: $e');
    }
  }

  /// Refresh all consent statuses for a specific bank
  Future<Map<String, dynamic>> refreshAllConsentsForBank(String bankCode) async {
    print('[AuthService] ===== Starting refresh for $bankCode =====');
    final results = <String, dynamic>{};

    // Refresh account consent
    try {
      print('[AuthService] Refreshing account consent...');
      final accountConsent = await refreshAccountConsentStatus(bankCode);
      results['account_consent'] = accountConsent != null ? 'refreshed' : 'not_found';
      print('[AuthService] Account consent result: ${results["account_consent"]}');
    } catch (e) {
      results['account_consent'] = 'error: $e';
      print('[AuthService] Account consent error: $e');
    }

    // Refresh payment consent
    try {
      print('[AuthService] Refreshing payment consent...');
      final paymentConsent = await refreshPaymentConsentStatus(bankCode);
      results['payment_consent'] = paymentConsent != null ? 'refreshed' : 'not_found';
      print('[AuthService] Payment consent result: ${results["payment_consent"]}');
    } catch (e) {
      results['payment_consent'] = 'error: $e';
      print('[AuthService] Payment consent error: $e');
    }

    // Refresh product consent
    try {
      print('[AuthService] Refreshing product consent...');
      final productConsent = await refreshProductConsentStatus(bankCode);
      results['product_consent'] = productConsent != null ? 'refreshed' : 'not_found';
      print('[AuthService] Product consent result: ${results["product_consent"]}');
    } catch (e) {
      results['product_consent'] = 'error: $e';
      print('[AuthService] Product consent error: $e');
    }

    print('[AuthService] ===== Refresh complete for $bankCode =====');
    print('[AuthService] Results: $results');

    return results;
  }

  /// Refresh all consents for all banks
  Future<Map<String, bool>> refreshAllConsents() async {
    final results = <String, bool>{};

    for (final bankCode in supportedBanks) {
      try {
        await refreshAllConsentsForBank(bankCode);
        results[bankCode] = true;
      } catch (e) {
        results[bankCode] = false;
      }
    }

    return results;
  }

  Future<void> initialize() async {
    await loadTokens();
    await loadConsents();
    _clientId = await getClientId();
  }

  Future<void> logout() async {
    _tokens.clear();
    _accountConsents.clear();
    _paymentConsents.clear();
    _productConsents.clear();
    _clientId = null;

    // Clear all sensitive data from secure storage
    await _secureStorage.clearAllAuthData();
  }

  bool get isAuthenticated => _clientId != null && _clientId!.isNotEmpty;

  List<String> get supportedBanks => ['vbank', 'abank', 'sbank', 'babank'];
}
