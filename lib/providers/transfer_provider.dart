import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../models/bank_account.dart';

class TransferProvider with ChangeNotifier {
  final AuthService _authService;
  final NotificationService _notificationService;

  bool _isProcessing = false;
  String? _error;
  String? _lastPaymentId;

  TransferProvider(this._authService, this._notificationService);

  bool get isProcessing => _isProcessing;
  String? get error => _error;
  String? get lastPaymentId => _lastPaymentId;

  /// Transfer money between accounts
  Future<bool> transferMoney({
    required BankAccount fromAccount,
    required BankAccount toAccount,
    required double amount,
    String? comment,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final clientId = _authService.clientId;
      final fromService = _authService.getBankService(fromAccount.bankCode);
      final isInterBank = fromAccount.bankCode != toAccount.bankCode;

      // Get the account consent ID for this bank
      final accountConsent = await _authService.getAccountConsent(fromAccount.bankCode);
      print('[$fromAccount.bankCode] Using account consent: ${accountConsent.consentId}');

      // NEW STRATEGY: Create a single_use consent for this specific transfer
      print('[$fromAccount.bankCode] Creating single_use payment consent for transfer');

      final singleUseConsent = await fromService.createPaymentConsent(
        clientId,
        fromAccount.identification ?? fromAccount.accountId,
        consentType: 'single_use',
        amount: amount,
        creditorAccount: toAccount.identification ?? toAccount.accountId,
        creditorName: toAccount.name ?? 'Recipient',
        reference: comment ?? 'Transfer',
      );

      print('[$fromAccount.bankCode] Single-use consent created: ${singleUseConsent.consentId}');

      // Wait a moment for consent to be processed
      await Future.delayed(const Duration(milliseconds: 500));

      // Create payment using BOTH the account consent and the payment consent
      final result = await fromService.createPayment(
        clientId: clientId,
        debtorAccountId: fromAccount.identification ?? fromAccount.accountId,
        creditorAccountId: toAccount.identification ?? toAccount.accountId,
        amount: amount,
        comment: comment,
        currency: fromAccount.currency,
        creditorBankCode: isInterBank ? toAccount.bankCode : null,
        accountConsentId: accountConsent.consentId,
        paymentConsentId: singleUseConsent.consentId,
      );

      _lastPaymentId = result['data']['paymentId'];
      _isProcessing = false;

      // Уведомление об успешном переводе
      _notificationService.addNotification(
        title: 'Перевод выполнен',
        message: 'Перевод $amount ${fromAccount.currency} на счет ${_maskAccountNumber(toAccount.displayName)}',
        type: NotificationType.success,
      );

      // Мониторинг статуса перевода
      _monitorPaymentStatus(_lastPaymentId!, fromAccount.bankCode);

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;

      // Уведомление об ошибке перевода
      _notificationService.addNotification(
        title: 'Ошибка перевода',
        message: 'Не удалось выполнить перевод: $e',
        type: NotificationType.error,
      );

      notifyListeners();
      return false;
    }
  }

  String _maskAccountNumber(String accountNumber) {
    if (accountNumber.length <= 4) return accountNumber;
    return '***${accountNumber.substring(accountNumber.length - 4)}';
  }

  /// Мониторинг статуса перевода
  void _monitorPaymentStatus(String paymentId, String bankCode) async {
    await Future.delayed(const Duration(seconds: 5));

    try {
      final status = await getPaymentStatus(paymentId, bankCode);

      if (status == 'ACSC') {
        _notificationService.addNotification(
          title: 'Перевод подтвержден',
          message: 'Перевод успешно завершен',
          type: NotificationType.success,
        );
      } else if (status == 'RJCT') {
        _notificationService.addNotification(
          title: 'Перевод отклонен',
          message: 'Банк отклонил операцию',
          type: NotificationType.error,
        );
      }
    } catch (e) {
      debugPrint('Error monitoring payment status: $e');
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