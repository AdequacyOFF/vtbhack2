import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

import '../models/transaction.dart';
import '../models/virtual_account.dart';

class ExpensesOptimizationService {
  static const String _apiUrl = 'http://5.129.212.83:51000/advice';

  /// Collect spending statistics by category for the last 30 days
  Map<String, double> collectMonthlySpending(List<BankTransaction> transactions) {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));

    debugPrint('[ExpensesOptimization] Collecting spending from $startDate to $now');
    debugPrint('[ExpensesOptimization] Total transactions to process: ${transactions.length}');

    final Map<String, double> categorySpending = {};

    // Initialize all categories with 0
    for (final category in ExpenseCategory.all) {
      categorySpending[_mapCategoryToEnglish(category)] = 0.0;
    }

    // Accumulate spending by category
    int processedCount = 0;
    for (final transaction in transactions) {
      final transactionDate = DateTime.tryParse(transaction.bookingDateTime);

      if (transactionDate != null && transactionDate.isAfter(startDate)) {
        // Only count debit transactions (expenses)
        if (!transaction.isCredit) {
          processedCount++;

          // transaction.category now uses MCC code + merchant category + keyword fallback
          final russianCategory = transaction.category;

          // Map to our standard expense categories
          String? mappedCategory;
          if (russianCategory == 'Еда' || russianCategory == 'Продукты') {
            mappedCategory = ExpenseCategory.food;
          } else if (russianCategory == 'Транспорт') {
            mappedCategory = ExpenseCategory.transport;
          } else if (russianCategory == 'Покупки') {
            mappedCategory = ExpenseCategory.shopping;
          } else if (russianCategory == 'Развлечения') {
            mappedCategory = ExpenseCategory.entertainment;
          } else if (russianCategory == 'Здоровье') {
            mappedCategory = ExpenseCategory.health;
          } else if (russianCategory == 'ЖКХ/Аренда' || russianCategory == 'Коммунальные услуги') {
            mappedCategory = ExpenseCategory.utilities;
          } else if (russianCategory == 'Образование') {
            mappedCategory = ExpenseCategory.education;
          } else {
            mappedCategory = ExpenseCategory.other;
          }

          final englishCategory = _mapCategoryToEnglish(mappedCategory);

          debugPrint('[ExpensesOptimization] Transaction #$processedCount: ${transaction.amountValue.abs()} ₽, '
              'Date: ${transactionDate.toString().substring(0, 10)}, '
              'Category from transaction: "$russianCategory", '
              'Mapped to: "$mappedCategory" (English: "$englishCategory"), '
              'MCC: "${transaction.merchant?.mccCode ?? 'N/A'}", '
              'Merchant: "${transaction.merchant?.name ?? 'N/A'}"');

          categorySpending[englishCategory] =
              (categorySpending[englishCategory] ?? 0.0) + transaction.amountValue.abs();
        }
      }
    }

    debugPrint('[ExpensesOptimization] Processed $processedCount expense transactions');

    debugPrint('[ExpensesOptimization] Final category spending: $categorySpending');
    return categorySpending;
  }

  /// Calculate total income from transactions for the last 30 days
  double calculateMonthlyIncome(List<BankTransaction> transactions) {
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));

    double income = 0.0;
    int incomeTransactions = 0;

    for (final transaction in transactions) {
      final transactionDate = DateTime.tryParse(transaction.bookingDateTime);

      if (transactionDate != null && transactionDate.isAfter(startDate)) {
        // Only count credit transactions (incoming money)
        if (transaction.isCredit) {
          income += transaction.amountValue.abs();
          incomeTransactions++;
        }
      }
    }

    debugPrint('[ExpensesOptimization] Found $incomeTransactions income transactions, total: $income ₽');
    return income;
  }

  /// Get optimized expenses advice from ML service
  Future<Map<String, dynamic>> getOptimizedExpenses({
    required List<BankTransaction> transactions,
    required String userWishes,
  }) async {
    try {
      // Collect current spending statistics
      final wastes = collectMonthlySpending(transactions);
      final earnings = calculateMonthlyIncome(transactions);

      debugPrint('[ExpensesOptimization] Current spending: $wastes');
      debugPrint('[ExpensesOptimization] Monthly income: $earnings');
      debugPrint('[ExpensesOptimization] User wishes: $userWishes');

      // Prepare request body
      final requestBody = {
        'wastes': wastes,
        'earnings': earnings,
        'wishes': userWishes,
      };

      debugPrint('[ExpensesOptimization] Sending request to $_apiUrl');
      debugPrint('[ExpensesOptimization] Request body: ${jsonEncode(requestBody)}');

      // Send POST request to ML service
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Timeout: сервер не ответил в течение 30 секунд');
        },
      );

      debugPrint('[ExpensesOptimization] Response status: ${response.statusCode}');
      debugPrint('[ExpensesOptimization] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;

        // Extract optimized wastes
        final optimizedWastes = (data['wastes'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );

        final optimizedEarnings = (data['earnings'] as num).toDouble();
        final comment = data['comment'] as String? ?? '';

        debugPrint('[ExpensesOptimization] Optimized spending: $optimizedWastes');
        debugPrint('[ExpensesOptimization] Optimized earnings: $optimizedEarnings');
        debugPrint('[ExpensesOptimization] AI Comment: $comment');

        return {
          'wastes': optimizedWastes,
          'earnings': optimizedEarnings,
          'comment': comment,
          'original_wastes': wastes,
          'original_earnings': earnings,
        };
      } else {
        throw Exception('Ошибка сервера: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ExpensesOptimization] Error: $e');
      rethrow;
    }
  }

  /// Map Russian category names to English for API
  String _mapCategoryToEnglish(String russianCategory) {
    switch (russianCategory) {
      case ExpenseCategory.food:
        return 'meal';
      case ExpenseCategory.transport:
        return 'transport';
      case ExpenseCategory.shopping:
        return 'shopping';
      case ExpenseCategory.entertainment:
        return 'entertainment';
      case ExpenseCategory.health:
        return 'health';
      case ExpenseCategory.utilities:
        return 'utilities';
      case ExpenseCategory.education:
        return 'education';
      case ExpenseCategory.other:
      default:
        return 'other';
    }
  }

  /// Map English category names back to Russian
  String mapEnglishToRussian(String englishCategory) {
    switch (englishCategory) {
      case 'meal':
        return ExpenseCategory.food;
      case 'transport':
        return ExpenseCategory.transport;
      case 'shopping':
        return ExpenseCategory.shopping;
      case 'entertainment':
        return ExpenseCategory.entertainment;
      case 'health':
        return ExpenseCategory.health;
      case 'utilities':
        return ExpenseCategory.utilities;
      case 'education':
        return ExpenseCategory.education;
      case 'other':
      default:
        return ExpenseCategory.other;
    }
  }
}
