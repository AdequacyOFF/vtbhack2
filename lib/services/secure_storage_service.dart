import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing sensitive data like tokens and credentials
/// Uses encrypted storage on device (Keychain on iOS, KeyStore on Android)
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;

  SecureStorageService._internal();

  // Configure secure storage with appropriate options
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  // Keys for sensitive data
  static const String _tokensKey = 'secure_bank_tokens';
  static const String _accountConsentsKey = 'secure_account_consents';
  static const String _paymentConsentsKey = 'secure_payment_consents';
  static const String _productConsentsKey = 'secure_product_consents';
  static const String _clientIdKey = 'secure_client_id';

  /// Write encrypted data
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read encrypted data
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete encrypted data
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Delete all encrypted data
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Check if key exists
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  // Specific methods for sensitive data

  /// Save bank tokens securely
  Future<void> saveTokens(String tokensJson) async {
    await write(_tokensKey, tokensJson);
  }

  /// Read bank tokens
  Future<String?> readTokens() async {
    return await read(_tokensKey);
  }

  /// Delete bank tokens
  Future<void> deleteTokens() async {
    await delete(_tokensKey);
  }

  /// Save account consents securely
  Future<void> saveAccountConsents(String consentsJson) async {
    await write(_accountConsentsKey, consentsJson);
  }

  /// Read account consents
  Future<String?> readAccountConsents() async {
    return await read(_accountConsentsKey);
  }

  /// Delete account consents
  Future<void> deleteAccountConsents() async {
    await delete(_accountConsentsKey);
  }

  /// Save payment consents securely
  Future<void> savePaymentConsents(String consentsJson) async {
    await write(_paymentConsentsKey, consentsJson);
  }

  /// Read payment consents
  Future<String?> readPaymentConsents() async {
    return await read(_paymentConsentsKey);
  }

  /// Delete payment consents
  Future<void> deletePaymentConsents() async {
    await delete(_paymentConsentsKey);
  }

  /// Save product consents securely
  Future<void> saveProductConsents(String consentsJson) async {
    await write(_productConsentsKey, consentsJson);
  }

  /// Read product consents
  Future<String?> readProductConsents() async {
    return await read(_productConsentsKey);
  }

  /// Delete product consents
  Future<void> deleteProductConsents() async {
    await delete(_productConsentsKey);
  }

  /// Save client ID securely
  Future<void> saveClientId(String clientId) async {
    await write(_clientIdKey, clientId);
  }

  /// Read client ID
  Future<String?> readClientId() async {
    return await read(_clientIdKey);
  }

  /// Delete client ID
  Future<void> deleteClientId() async {
    await delete(_clientIdKey);
  }

  /// Clear all sensitive authentication data
  Future<void> clearAllAuthData() async {
    await deleteTokens();
    await deleteAccountConsents();
    await deletePaymentConsents();
    await deleteProductConsents();
    await deleteClientId();
  }
}
