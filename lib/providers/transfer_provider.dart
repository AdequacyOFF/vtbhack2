import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/bank_account.dart';

class TransferProvider with ChangeNotifier {
  final AuthService _authService;

  bool _isProcessing = false;
  String? _error;
  String? _lastPaymentId;

  TransferProvider(this._authService);

  bool get isProcessing => _isProcessing;
  String? get error => _error;
  String? get lastPaymentId => _lastPaymentId;

  /// Transfer money between accounts
  Future<bool> transferMoney({
    required BankAccount fromAccount,
    required BankAccount toAccount,
    required double amount,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final clientId = _authService.clientId;
      final fromService = _authService.getBankService(fromAccount.bankCode);

      // Get payment consent for the source bank
      final paymentConsent = await _authService.getPaymentConsent(
        fromAccount.bankCode,
        fromAccount.identification ?? fromAccount.accountId,
      );

      if (!paymentConsent.isApproved) {
        throw Exception('Payment consent not approved');
      }

      // Determine if it's an inter-bank transfer
      final isInterBank = fromAccount.bankCode != toAccount.bankCode;

      // Create payment
      final result = await fromService.createPayment(
        clientId: clientId,
        debtorAccountId: fromAccount.identification ?? fromAccount.accountId,
        creditorAccountId: toAccount.identification ?? toAccount.accountId,
        amount: amount,
        currency: fromAccount.currency,
        creditorBankCode: isInterBank ? toAccount.bankCode : null,
        paymentConsentId: paymentConsent.consentId,
      );

      _lastPaymentId = result['data']['paymentId'];
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  /// Get payment status
  Future<String?> getPaymentStatus(String paymentId, String bankCode) async {
    try {
      final service = _authService.getBankService(bankCode);
      final result = await service.getPaymentStatus(paymentId);
      return result['data']['status'];
    } catch (e) {
      debugPrint('Error getting payment status: $e');
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
