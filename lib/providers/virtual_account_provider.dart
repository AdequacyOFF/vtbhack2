import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';

import '../models/virtual_account.dart';
import '../models/transaction.dart';
import '../services/notification_service.dart';

class VirtualAccountProvider with ChangeNotifier {
  final NotificationService _notificationService;
  final _uuid = const Uuid();

  List<VirtualAccount> _virtualAccounts = [];
  bool _isLoading = false;
  String? _error;
  double _lastMonthIncome = 0.0;

  static const String _storageKey = 'virtual_accounts';
  static const String _incomeKey = 'last_month_income';

  VirtualAccountProvider(this._notificationService) {
    loadVirtualAccounts();
    _loadLastMonthIncome();
  }

  List<VirtualAccount> get virtualAccounts => _virtualAccounts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get lastMonthIncome => _lastMonthIncome;

  double get totalAllocated {
    return _virtualAccounts.fold(0.0, (sum, account) => sum + account.allocatedAmount);
  }

  double get totalSpent {
    return _virtualAccounts.fold(0.0, (sum, account) => sum + account.spentAmount);
  }

  double get totalRemaining {
    return _virtualAccounts.fold(0.0, (sum, account) => sum + account.remainingAmount);
  }

  /// Potential earnings = Last month's income - Planned expenses (total allocated)
  double get potentialEarnings {
    return _lastMonthIncome - totalAllocated;
  }

  /// Load last month's income from storage
  Future<void> _loadLastMonthIncome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastMonthIncome = prefs.getDouble(_incomeKey) ?? 0.0;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading last month income: $e');
    }
  }

  /// Save last month's income to storage
  Future<void> _saveLastMonthIncome() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_incomeKey, _lastMonthIncome);
    } catch (e) {
      debugPrint('Error saving last month income: $e');
    }
  }

  /// Calculate and update last month's income from transactions
  Future<void> calculateLastMonthIncome(List<BankTransaction> allTransactions) async {
    final now = DateTime.now();
    final lastMonth = DateTime(now.year, now.month - 1);
    final lastMonthStart = DateTime(lastMonth.year, lastMonth.month, 1);
    final lastMonthEnd = DateTime(lastMonth.year, lastMonth.month + 1, 1).subtract(const Duration(days: 1));

    double income = 0.0;

    for (final transaction in allTransactions) {
      final transactionDate = DateTime.tryParse(transaction.bookingDateTime);
      if (transactionDate != null &&
          transactionDate.isAfter(lastMonthStart.subtract(const Duration(days: 1))) &&
          transactionDate.isBefore(lastMonthEnd.add(const Duration(days: 1)))) {
        // Only count credit transactions (incoming money)
        if (transaction.isCredit) {
          income += transaction.amountValue.abs();
        }
      }
    }

    _lastMonthIncome = income;
    await _saveLastMonthIncome();
    notifyListeners();
  }

  /// Load virtual accounts from storage
  Future<void> loadVirtualAccounts() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsJson = prefs.getString(_storageKey);

      if (accountsJson != null) {
        final accountsList = jsonDecode(accountsJson) as List;
        _virtualAccounts = accountsList
            .map((json) => VirtualAccount.fromJson(json))
            .toList();

        // Check if we need to reset for new month
        await _checkAndResetForNewMonth();
      }

      _isLoading = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save virtual accounts to storage
  Future<void> _saveVirtualAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountsList = _virtualAccounts.map((account) => account.toJson()).toList();
      await prefs.setString(_storageKey, jsonEncode(accountsList));
    } catch (e) {
      debugPrint('Error saving virtual accounts: $e');
    }
  }

  /// Check if month has changed and reset spent amounts
  Future<void> _checkAndResetForNewMonth() async {
    final currentMonthYear = VirtualAccount.getCurrentMonthYear();
    bool hasChanges = false;

    for (int i = 0; i < _virtualAccounts.length; i++) {
      if (_virtualAccounts[i].monthYear != currentMonthYear) {
        _virtualAccounts[i] = _virtualAccounts[i].copyWith(
          monthYear: currentMonthYear,
          spentAmount: 0.0,
        );
        hasChanges = true;
      }
    }

    if (hasChanges) {
      await _saveVirtualAccounts();
      notifyListeners();
    }
  }

  /// Create a new virtual account
  Future<void> createVirtualAccount({
    required String category,
    required double allocatedAmount,
  }) async {
    if (allocatedAmount <= 0) {
      throw Exception('Allocated amount must be greater than 0');
    }

    // Check if account for this category already exists
    final existingAccount = _virtualAccounts.firstWhere(
      (account) => account.category == category,
      orElse: () => VirtualAccount(
        id: '',
        category: '',
        allocatedAmount: 0,
        spentAmount: 0,
        monthYear: '',
        createdAt: DateTime.now(),
      ),
    );

    if (existingAccount.id.isNotEmpty) {
      throw Exception('Virtual account for category "$category" already exists');
    }

    final newAccount = VirtualAccount(
      id: _uuid.v4(),
      category: category,
      allocatedAmount: allocatedAmount,
      spentAmount: 0.0,
      monthYear: VirtualAccount.getCurrentMonthYear(),
      createdAt: DateTime.now(),
    );

    _virtualAccounts.add(newAccount);
    await _saveVirtualAccounts();
    notifyListeners();

    _notificationService.addNotification(
      title: 'Виртуальный счет создан',
      message: 'Создан счет "$category" на ${allocatedAmount.toStringAsFixed(2)} ₽',
      type: NotificationType.success,
    );
  }

  /// Update virtual account allocated amount
  Future<void> updateVirtualAccount({
    required String accountId,
    required double newAllocatedAmount,
  }) async {
    if (newAllocatedAmount <= 0) {
      throw Exception('Allocated amount must be greater than 0');
    }

    final index = _virtualAccounts.indexWhere((account) => account.id == accountId);
    if (index == -1) {
      throw Exception('Virtual account not found');
    }

    _virtualAccounts[index] = _virtualAccounts[index].copyWith(
      allocatedAmount: newAllocatedAmount,
    );

    await _saveVirtualAccounts();
    notifyListeners();

    _notificationService.addNotification(
      title: 'Счет обновлен',
      message: 'Лимит счета "${_virtualAccounts[index].category}" изменен на ${newAllocatedAmount.toStringAsFixed(2)} ₽',
      type: NotificationType.info,
    );
  }

  /// Delete virtual account
  Future<void> deleteVirtualAccount(String accountId) async {
    final account = _virtualAccounts.firstWhere(
      (account) => account.id == accountId,
      orElse: () => VirtualAccount(
        id: '',
        category: '',
        allocatedAmount: 0,
        spentAmount: 0,
        monthYear: '',
        createdAt: DateTime.now(),
      ),
    );

    if (account.id.isEmpty) {
      throw Exception('Virtual account not found');
    }

    _virtualAccounts.removeWhere((account) => account.id == accountId);
    await _saveVirtualAccounts();
    notifyListeners();

    _notificationService.addNotification(
      title: 'Счет удален',
      message: 'Виртуальный счет "${account.category}" удален',
      type: NotificationType.info,
    );
  }

  /// Process transaction and update relevant virtual account
  Future<void> processTransaction(BankTransaction transaction) async {
    // Only process debit transactions (expenses)
    if (transaction.isCredit) return;

    // Map transaction category to virtual account category
    final mappedCategory = ExpenseCategory.mapTransactionCategory(transaction.category);
    if (mappedCategory == null) return;

    // Find virtual account for this category
    final accountIndex = _virtualAccounts.indexWhere(
      (account) => account.category == mappedCategory,
    );

    if (accountIndex == -1) return; // No virtual account for this category

    final account = _virtualAccounts[accountIndex];
    final transactionAmount = transaction.amountValue.abs();

    // Check if this would exhaust the account
    final wasExhausted = account.isExhausted;
    final newSpentAmount = account.spentAmount + transactionAmount;

    // Update spent amount
    _virtualAccounts[accountIndex] = account.copyWith(
      spentAmount: newSpentAmount,
    );

    await _saveVirtualAccounts();
    notifyListeners();

    // Notify if account is now exhausted (but wasn't before)
    final isNowExhausted = _virtualAccounts[accountIndex].isExhausted;
    if (isNowExhausted && !wasExhausted) {
      _notificationService.addNotification(
        title: 'Бюджет исчерпан!',
        message: 'Лимит виртуального счета "${account.category}" исчерпан',
        type: NotificationType.warning,
      );
    }
  }

  /// Process multiple transactions (for batch processing)
  Future<void> processTransactions(List<BankTransaction> transactions) async {
    for (final transaction in transactions) {
      await processTransaction(transaction);
    }
  }

  /// Get virtual account by category
  VirtualAccount? getAccountByCategory(String category) {
    try {
      return _virtualAccounts.firstWhere((account) => account.category == category);
    } catch (e) {
      return null;
    }
  }

  /// Get virtual account by ID
  VirtualAccount? getAccountById(String accountId) {
    try {
      return _virtualAccounts.firstWhere((account) => account.id == accountId);
    } catch (e) {
      return null;
    }
  }

  /// Get available categories (not yet used)
  List<String> getAvailableCategories() {
    final usedCategories = _virtualAccounts.map((account) => account.category).toSet();
    return ExpenseCategory.all.where((category) => !usedCategories.contains(category)).toList();
  }

  /// Refresh data (useful after transactions are loaded)
  Future<void> refresh() async {
    await loadVirtualAccounts();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
