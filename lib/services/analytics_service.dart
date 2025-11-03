import '../models/transaction.dart';

class TransactionCategory {
  final String category;
  final int count;
  final double totalAmount;

  TransactionCategory({
    required this.category,
    required this.count,
    required this.totalAmount,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'count': count,
      'totalAmount': totalAmount,
      'averageAmount': count > 0 ? totalAmount / count : 0,
    };
  }
}

class AnalyticsService {
  /// Analyzes transactions and returns an array of the most frequent transaction types
  /// sorted by frequency, ready to be sent to ML service
  static List<Map<String, dynamic>> getTransactionFrequencyAnalysis(
    List<BankTransaction> transactions,
  ) {
    // Count transactions by category
    final categoryMap = <String, List<BankTransaction>>{};

    for (var transaction in transactions) {
      final category = transaction.category;
      if (!categoryMap.containsKey(category)) {
        categoryMap[category] = [];
      }
      categoryMap[category]!.add(transaction);
    }

    // Create category statistics
    final categoryStats = <TransactionCategory>[];
    categoryMap.forEach((category, txList) {
      final totalAmount = txList.fold<double>(
        0,
        (sum, tx) => sum + tx.amountValue,
      );

      categoryStats.add(TransactionCategory(
        category: category,
        count: txList.length,
        totalAmount: totalAmount,
      ));
    });

    // Sort by frequency (count)
    categoryStats.sort((a, b) => b.count.compareTo(a.count));

    // Convert to JSON format for ML service
    return categoryStats.map((stat) => stat.toJson()).toList();
  }

  /// Get spending patterns for specific time periods
  static Map<String, dynamic> getSpendingPatterns(
    List<BankTransaction> transactions,
  ) {
    final now = DateTime.now();
    final last30Days = now.subtract(const Duration(days: 30));
    final last7Days = now.subtract(const Duration(days: 7));

    double totalSpent30Days = 0;
    double totalSpent7Days = 0;
    double totalIncome30Days = 0;
    double totalIncome7Days = 0;

    for (var tx in transactions) {
      final txDate = DateTime.tryParse(tx.bookingDateTime);
      if (txDate == null) continue;

      if (txDate.isAfter(last30Days)) {
        if (tx.isDebit) {
          totalSpent30Days += tx.amountValue;
        } else {
          totalIncome30Days += tx.amountValue;
        }

        if (txDate.isAfter(last7Days)) {
          if (tx.isDebit) {
            totalSpent7Days += tx.amountValue;
          } else {
            totalIncome7Days += tx.amountValue;
          }
        }
      }
    }

    return {
      'last_30_days': {
        'total_spent': totalSpent30Days,
        'total_income': totalIncome30Days,
        'net': totalIncome30Days - totalSpent30Days,
        'daily_average_spent': totalSpent30Days / 30,
      },
      'last_7_days': {
        'total_spent': totalSpent7Days,
        'total_income': totalIncome7Days,
        'net': totalIncome7Days - totalSpent7Days,
        'daily_average_spent': totalSpent7Days / 7,
      },
    };
  }

  /// Get top merchants/transaction descriptions
  static List<Map<String, dynamic>> getTopMerchants(
    List<BankTransaction> transactions,
    {int limit = 10}
  ) {
    final merchantMap = <String, int>{};

    for (var tx in transactions) {
      final info = tx.transactionInformation ?? 'Unknown';
      merchantMap[info] = (merchantMap[info] ?? 0) + 1;
    }

    final merchantList = merchantMap.entries.map((entry) {
      return {
        'merchant': entry.key,
        'transaction_count': entry.value,
      };
    }).toList();

    merchantList.sort((a, b) => (b['transaction_count'] as int).compareTo(a['transaction_count'] as int));

    return merchantList.take(limit).toList();
  }

  /// Export all analytics data for ML service
  static Map<String, dynamic> exportForML(List<BankTransaction> transactions) {
    return {
      'transaction_frequency': getTransactionFrequencyAnalysis(transactions),
      'spending_patterns': getSpendingPatterns(transactions),
      'top_merchants': getTopMerchants(transactions),
      'total_transactions': transactions.length,
      'total_debit_transactions': transactions.where((tx) => tx.isDebit).length,
      'total_credit_transactions': transactions.where((tx) => tx.isCredit).length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
