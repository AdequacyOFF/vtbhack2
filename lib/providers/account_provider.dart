import 'package:flutter/foundation.dart';
import '../models/bank_account.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class AccountProvider with ChangeNotifier {
  final AuthService _authService;
  final NotificationService _notificationService;

  List<BankAccount> _accounts = [];
  Map<String, double> _balances = {};
  Map<String, List<BankTransaction>> _transactions = {};
  final Map<String, double> _previousBalances = {};

  bool _isLoading = false;
  String? _error;

  AccountProvider(this._authService, this._notificationService);

  List<BankAccount> get accounts => _accounts;
  Map<String, double> get balances => _balances;
  Map<String, List<BankTransaction>> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalBalance {
    return _balances.values.fold(0.0, (sum, balance) => sum + balance);
  }

  /// Creates a unique key for balance storage by combining bank code and account ID
  String _getBalanceKey(String bankCode, String accountId) {
    return '$bankCode:$accountId';
  }

  /// Gets balance for a specific account using composite key
  double getBalance(BankAccount account) {
    final balanceKey = _getBalanceKey(account.bankCode, account.accountId);
    return _balances[balanceKey] ?? 0.0;
  }

  /// Gets balance by accountId and bankCode (for when you don't have the account object)
  double getBalanceByIds(String bankCode, String accountId) {
    final balanceKey = _getBalanceKey(bankCode, accountId);
    return _balances[balanceKey] ?? 0.0;
  }

  List<BankAccount> get accountsSortedByBalance {
    final accountsWithBalance = _accounts.map((account) {
      final balanceKey = _getBalanceKey(account.bankCode, account.accountId);
      return account.copyWith(balance: _balances[balanceKey]);
    }).toList();

    accountsWithBalance.sort((a, b) => (b.balance ?? 0).compareTo(a.balance ?? 0));
    return accountsWithBalance;
  }

  final Map<String, String> _consentErrors = {};

  Map<String, String> get consentErrors => _consentErrors;

  /// Fetches all accounts from all connected banks
  Future<void> fetchAllAccounts() async {
    _isLoading = true;
    _error = null;
    _consentErrors.clear();
    notifyListeners();

    try {
      final clientId = _authService.clientId;
      if (clientId.isEmpty) {
        throw Exception('Client ID not set');
      }

      final allAccounts = <BankAccount>[];
      final allBalances = <String, double>{};

      // Сохраняем предыдущие балансы для сравнения
      final previousBalances = Map<String, double>.from(_balances);

      // Fetch from all banks
      for (final bankCode in _authService.supportedBanks) {
        try {
          final service = _authService.getBankService(bankCode);

          // Ensure we have consent
          final consent = await _authService.getAccountConsent(bankCode);

          if (consent.isApproved) {
            // Fetch accounts
            final accounts = await service.getAccounts(clientId, consent.consentId);
            allAccounts.addAll(accounts);

            // Fetch balances for each account
            for (final account in accounts) {
              try {
                final balanceData = await service.getBalance(account.accountId, consent.consentId);
                final newBalance = balanceData['balance'] ?? 0.0;
                final balanceKey = _getBalanceKey(bankCode, account.accountId);
                allBalances[balanceKey] = newBalance;

                // Проверяем изменение баланса
                _checkBalanceChange(account, newBalance, previousBalances[balanceKey]);
              } catch (e) {
                debugPrint('Error fetching balance for ${account.accountId}: $e');
                final balanceKey = _getBalanceKey(bankCode, account.accountId);
                allBalances[balanceKey] = 0.0;
              }
            }
          } else if (consent.isPending) {
            // Consent is pending manual approval
            _consentErrors[bankCode] = 'Требуется подтверждение согласия в банке';
            _notificationService.addNotification(
              title: 'Требуется подтверждение',
              message: 'Согласие с ${_getBankName(bankCode)} ожидает подтверждения',
              type: NotificationType.warning,
            );
            debugPrint('Consent pending for $bankCode - manual approval required');
          }
        } catch (e) {
          final errorMsg = e.toString();
          debugPrint('Error fetching accounts from $bankCode: $e');

          // Check if it's a consent error
          if (errorMsg.contains('CONSENT_REQUIRED') || errorMsg.contains('consent')) {
            _consentErrors[bankCode] = 'Требуется создание или подтверждение согласия';
            _notificationService.addNotification(
              title: 'Проблема с согласием',
              message: 'Требуется обновить согласие с ${_getBankName(bankCode)}',
              type: NotificationType.error,
            );
          } else {
            _consentErrors[bankCode] = 'Ошибка загрузки данных';
          }
        }
      }

      _accounts = allAccounts;
      _balances = allBalances;

      // Automatically fetch transactions for all accounts
      debugPrint('[AccountProvider] Auto-fetching transactions for ${allAccounts.length} accounts');
      for (final account in allAccounts) {
        try {
          final service = _authService.getBankService(account.bankCode);
          final consent = await _authService.getAccountConsent(account.bankCode);

          if (consent.isApproved) {
            final previousTransactions = _transactions[account.accountId] ?? [];
            final newTransactions = await service.getTransactions(
              account.accountId,
              consent.consentId,
              fromDate: DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
              toDate: DateTime.now().toIso8601String(),
            );

            _transactions[account.accountId] = newTransactions;
            debugPrint('[AccountProvider] Loaded ${newTransactions.length} transactions for account ${account.accountId}');

            // Check for new transactions
            _checkNewTransactions(account, newTransactions, previousTransactions);
          }
        } catch (e) {
          debugPrint('Error auto-fetching transactions for ${account.accountId}: $e');
          // Don't fail the whole operation if one account's transactions fail
        }
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Проверяет изменение баланса и создает уведомление
  void _checkBalanceChange(BankAccount account, double newBalance, double? oldBalance) {
    if (oldBalance != null && oldBalance != newBalance) {
      final difference = newBalance - oldBalance;
      final absDifference = difference.abs();

      if (absDifference > 0.01) {
        final direction = difference > 0 ? 'поступило' : 'списано';
        final amount = absDifference.toStringAsFixed(2);

        _notificationService.addNotification(
          title: 'Изменение баланса',
          message: 'На счет ${_maskAccountNumber(account.displayName)} $direction $amount ${account.currency}',
          type: difference > 0 ? NotificationType.success : NotificationType.info,
        );
      }
    }
  }

  String _maskAccountNumber(String accountNumber) {
    if (accountNumber.length <= 4) return accountNumber;
    return '***${accountNumber.substring(accountNumber.length - 4)}';
  }

  String _getBankName(String bankCode) {
    switch (bankCode) {
      case 'vbank': return 'ВТБ';
      case 'abank': return 'Альфа-Банк';
      case 'sbank': return 'Сбербанк';
      default: return bankCode;
    }
  }

  /// Fetches transactions for a specific account
  Future<void> fetchTransactionsForAccount(String accountId) async {
    try {
      final account = _accounts.firstWhere((acc) => acc.accountId == accountId);
      final service = _authService.getBankService(account.bankCode);
      final consent = await _authService.getAccountConsent(account.bankCode);

      if (consent.isApproved) {
        final previousTransactions = _transactions[accountId] ?? [];
        final newTransactions = await service.getTransactions(
          accountId,
          consent.consentId,
          fromDate: DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
          toDate: DateTime.now().toIso8601String(),
        );

        _transactions[accountId] = newTransactions;

        // Проверяем новые транзакции
        _checkNewTransactions(account, newTransactions, previousTransactions);

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching transactions for $accountId: $e');
    }
  }

  /// Проверяет новые транзакции и создает уведомления
  void _checkNewTransactions(BankAccount account, List<BankTransaction> newTransactions, List<BankTransaction> previousTransactions) {
    final previousIds = previousTransactions.map((t) => t.transactionId).toSet();
    final newOnes = newTransactions.where((t) => !previousIds.contains(t.transactionId)).toList();

    for (final transaction in newOnes) {
      // Преобразуем bookingDateTime в DateTime
      final bookingDate = DateTime.tryParse(transaction.bookingDateTime);
      if (bookingDate != null && bookingDate.isAfter(DateTime.now().subtract(const Duration(hours: 24)))) {
        final amount = transaction.amountValue;
        final direction = transaction.isCredit ? 'Поступление' : 'Списание';
        final description = transaction.transactionInformation ?? "Без описания";

        _notificationService.addNotification(
          title: 'Новая операция',
          message: '$direction: ${amount.toStringAsFixed(2)} ${transaction.currency} - $description',
          type: transaction.isCredit ? NotificationType.success : NotificationType.info,
        );
      }
    }
  }

  /// Fetches transactions for all accounts
  Future<void> fetchAllTransactions() async {
    for (final account in _accounts) {
      await fetchTransactionsForAccount(account.accountId);
    }
  }

  /// Get account by ID
  BankAccount? getAccountById(String accountId) {
    try {
      return _accounts.firstWhere((acc) => acc.accountId == accountId);
    } catch (e) {
      return null;
    }
  }

  /// Get all transactions across all accounts
  List<BankTransaction> get allTransactions {
    final allTx = <BankTransaction>[];
    _transactions.forEach((accountId, txList) {
      allTx.addAll(txList);
    });

    // Сортируем по bookingDateTime (преобразуя в DateTime)
    allTx.sort((a, b) {
      final dateA = DateTime.tryParse(a.bookingDateTime) ?? DateTime(0);
      final dateB = DateTime.tryParse(b.bookingDateTime) ?? DateTime(0);
      return dateB.compareTo(dateA);
    });
    return allTx;
  }

  /// Get accounts grouped by bank
  Map<String, List<BankAccount>> get accountsByBank {
    final grouped = <String, List<BankAccount>>{};
    for (final account in _accounts) {
      if (!grouped.containsKey(account.bankCode)) {
        grouped[account.bankCode] = [];
      }
      grouped[account.bankCode]!.add(account);
    }
    return grouped;
  }

  /// Refresh data
  /// Note: fetchAllAccounts() now automatically loads transactions, so no need to call fetchAllTransactions() separately
  Future<void> refresh() async {
    await fetchAllAccounts();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}