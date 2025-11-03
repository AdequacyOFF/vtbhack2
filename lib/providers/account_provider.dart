import 'package:flutter/foundation.dart';
import '../models/bank_account.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';

class AccountProvider with ChangeNotifier {
  final AuthService _authService;

  List<BankAccount> _accounts = [];
  Map<String, double> _balances = {};
  Map<String, List<BankTransaction>> _transactions = {};

  bool _isLoading = false;
  String? _error;

  AccountProvider(this._authService);

  List<BankAccount> get accounts => _accounts;
  Map<String, double> get balances => _balances;
  Map<String, List<BankTransaction>> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  double get totalBalance {
    return _balances.values.fold(0.0, (sum, balance) => sum + balance);
  }

  List<BankAccount> get accountsSortedByBalance {
    final accountsWithBalance = _accounts.map((account) {
      return account.copyWith(balance: _balances[account.accountId]);
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
                allBalances[account.accountId] = balanceData['balance'] ?? 0.0;
              } catch (e) {
                debugPrint('Error fetching balance for ${account.accountId}: $e');
                allBalances[account.accountId] = 0.0;
              }
            }
          } else if (consent.isPending) {
            // Consent is pending manual approval
            _consentErrors[bankCode] = 'Требуется подтверждение согласия в банке';
            debugPrint('Consent pending for $bankCode - manual approval required');
          }
        } catch (e) {
          final errorMsg = e.toString();
          debugPrint('Error fetching accounts from $bankCode: $e');

          // Check if it's a consent error
          if (errorMsg.contains('CONSENT_REQUIRED') || errorMsg.contains('consent')) {
            _consentErrors[bankCode] = 'Требуется создание или подтверждение согласия';
          } else {
            _consentErrors[bankCode] = 'Ошибка загрузки данных';
          }
          // Continue with other banks even if one fails
        }
      }

      _accounts = allAccounts;
      _balances = allBalances;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetches transactions for a specific account
  Future<void> fetchTransactionsForAccount(String accountId) async {
    try {
      final account = _accounts.firstWhere((acc) => acc.accountId == accountId);
      final service = _authService.getBankService(account.bankCode);
      final consent = await _authService.getAccountConsent(account.bankCode);

      if (consent.isApproved) {
        final transactions = await service.getTransactions(
          accountId,
          consent.consentId,
          fromDate: DateTime.now().subtract(const Duration(days: 365)).toIso8601String(),
          toDate: DateTime.now().toIso8601String(),
        );

        _transactions[accountId] = transactions;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching transactions for $accountId: $e');
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

    // Sort by date descending
    allTx.sort((a, b) => b.bookingDateTime.compareTo(a.bookingDateTime));
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
  Future<void> refresh() async {
    await fetchAllAccounts();
    await fetchAllTransactions();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
