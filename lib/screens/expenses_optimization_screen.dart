import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../providers/account_provider.dart';
import '../providers/virtual_account_provider.dart';
import '../providers/product_provider.dart';
import '../services/expenses_optimization_service.dart';
import '../config/app_theme.dart';
import '../config/api_config.dart';

class ExpensesOptimizationScreen extends StatefulWidget {
  const ExpensesOptimizationScreen({super.key});

  @override
  State<ExpensesOptimizationScreen> createState() => _ExpensesOptimizationScreenState();
}

class _ExpensesOptimizationScreenState extends State<ExpensesOptimizationScreen> {
  final _optimizationService = ExpensesOptimizationService();
  final _wishesController = TextEditingController();

  Map<String, double>? _currentSpending;
  Map<String, double>? _optimizedSpending;
  double _currentIncome = 0.0;
  double _optimizedIncome = 0.0;
  bool _isLoading = false;
  bool _hasOptimization = false;
  bool _isCreatingDeposit = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentStatistics();
  }

  @override
  void dispose() {
    _wishesController.dispose();
    super.dispose();
  }

  void _loadCurrentStatistics() {
    final accountProvider = context.read<AccountProvider>();
    final transactions = accountProvider.allTransactions;

    setState(() {
      _currentSpending = _optimizationService.collectMonthlySpending(transactions);
      _currentIncome = _optimizationService.calculateMonthlyIncome(transactions);
    });
  }

  Future<void> _getOptimizationAdvice() async {
    if (_wishesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ваши пожелания по распределению финансов')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final accountProvider = context.read<AccountProvider>();
      final transactions = accountProvider.allTransactions;

      final result = await _optimizationService.getOptimizedExpenses(
        transactions: transactions,
        userWishes: _wishesController.text.trim(),
      );

      setState(() {
        _optimizedSpending = result['wastes'] as Map<String, double>;
        _optimizedIncome = result['earnings'] as double;
        _hasOptimization = true;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Оптимизация получена успешно!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createVirtualAccountsFromOptimization() async {
    if (_optimizedSpending == null) return;

    final virtualAccountProvider = context.read<VirtualAccountProvider>();

    try {
      int createdCount = 0;

      for (final entry in _optimizedSpending!.entries) {
        final russianCategory = _optimizationService.mapEnglishToRussian(entry.key);
        final amount = entry.value;

        // Skip if amount is 0 or negative
        if (amount <= 0) continue;

        // Check if account already exists
        final existingAccount = virtualAccountProvider.getAccountByCategory(russianCategory);
        if (existingAccount != null) {
          // Update existing account
          await virtualAccountProvider.updateVirtualAccount(
            accountId: existingAccount.id,
            newAllocatedAmount: amount,
          );
        } else {
          // Create new account
          await virtualAccountProvider.createVirtualAccount(
            category: russianCategory,
            allocatedAmount: amount,
          );
        }
        createdCount++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Создано/обновлено $createdCount виртуальных счетов'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при создании счетов: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createDepositInBABank() async {
    if (_currentSpending == null || _optimizedSpending == null) return;

    final savings = _getTotalSpending(_currentSpending!) - _getTotalSpending(_optimizedSpending!);

    if (savings <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет экономии для создания вклада'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isCreatingDeposit = true;
    });

    try {
      final productProvider = context.read<ProductProvider>();

      // Fetch products if not loaded
      if (productProvider.productsByBank.isEmpty) {
        await productProvider.fetchAllProducts();
      }

      // Get Best ADOFF Bank deposits
      final babankProducts = productProvider.productsByBank['babank'] ?? [];
      final babankDeposits = babankProducts.where((p) => p.isDeposit).toList();

      if (babankDeposits.isEmpty) {
        throw Exception('Нет доступных вкладов в Best ADOFF Bank');
      }

      // Find best deposit for the savings amount
      final validDeposits = babankDeposits.where((p) {
        final minAmount = p.minAmountValue;
        final maxAmount = p.maxAmountValue;
        if (minAmount != null && savings < minAmount) return false;
        if (maxAmount != null && savings > maxAmount) return false;
        return true;
      }).toList();

      if (validDeposits.isEmpty) {
        throw Exception('Сумма ${savings.toStringAsFixed(2)} ₽ не подходит для доступных вкладов');
      }

      // Sort by interest rate (highest first)
      validDeposits.sort((a, b) {
        final rateA = a.interestRateValue ?? 0;
        final rateB = b.interestRateValue ?? 0;
        return rateB.compareTo(rateA);
      });

      final bestDeposit = validDeposits.first;

      // Get source account from Best ADOFF Bank with sufficient balance
      final accountProvider = context.read<AccountProvider>();
      final accounts = accountProvider.accounts;

      // Filter accounts from Best ADOFF Bank only
      final babankAccounts = accounts.where((acc) => acc.bankCode == 'babank').toList();

      if (babankAccounts.isEmpty) {
        throw Exception('У вас нет счетов в Best ADOFF Bank. Создайте счет для открытия вклада.');
      }

      String? sourceAccountId;
      for (final account in babankAccounts) {
        final balance = accountProvider.getBalance(account);
        if (balance >= savings) {
          sourceAccountId = account.accountId;
          break;
        }
      }

      if (sourceAccountId == null) {
        // Check if any babank account exists but with insufficient balance
        final totalBabankBalance = babankAccounts.fold<double>(
          0.0,
          (sum, acc) => sum + accountProvider.getBalance(acc),
        );

        throw Exception(
          'Недостаточно средств на счетах Best ADOFF Bank.\n'
          'Необходимо: ${savings.toStringAsFixed(2)} ₽\n'
          'Доступно: ${totalBabankBalance.toStringAsFixed(2)} ₽\n'
          'Пополните счет или переведите средства из других банков.'
        );
      }

      // Create deposit
      await productProvider.openProduct(
        product: bestDeposit,
        amount: savings,
        termMonths: 12, // Default 12 months
        sourceAccountId: sourceAccountId,
      );

      setState(() {
        _isCreatingDeposit = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Вклад на ${savings.toStringAsFixed(2)} ₽ успешно создан в Best ADOFF Bank под ${bestDeposit.interestRateValue}%',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCreatingDeposit = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при создании вклада: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Оптимизация расходов'),
        elevation: 0,
      ),
      body: _currentSpending == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current spending section
                  _buildSectionTitle('Ваши расходы за последние 30 дней'),
                  const SizedBox(height: 16),
                  _buildSpendingChart(_currentSpending!, _currentIncome, 'current'),
                  const SizedBox(height: 8),
                  _buildBalanceCard(
                    'Баланс за последние 30 дней',
                    _currentIncome - _getTotalSpending(_currentSpending!),
                  ),

                  const SizedBox(height: 32),

                  // Wishes input section
                  _buildSectionTitle('Ваши пожелания'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _wishesController,
                    maxLines: 4,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                    enableSuggestions: true,
                    autocorrect: true,
                    enableIMEPersonalizedLearning: true,
                    decoration: const InputDecoration(
                      hintText: 'Например: Хочу накопить на отпуск 50000₽, снизить расходы на развлечения...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _getOptimizationAdvice,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_isLoading ? 'Получение рекомендаций...' : 'Получить рекомендации'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Optimized spending section (only shown after optimization)
                  if (_hasOptimization && _optimizedSpending != null) ...[
                    const SizedBox(height: 32),
                    _buildSectionTitle('Рекомендуемые расходы'),
                    const SizedBox(height: 16),
                    _buildSpendingChart(_optimizedSpending!, _optimizedIncome, 'optimized'),
                    const SizedBox(height: 8),
                    _buildBalanceCard(
                      'Прогнозируемый баланс',
                      _optimizedIncome - _getTotalSpending(_optimizedSpending!),
                    ),
                    const SizedBox(height: 16),

                    // Comparison card
                    _buildComparisonCard(),

                    const SizedBox(height: 24),

                    // Create deposit in Best ADOFF Bank button (only if there are savings)
                    if (_getTotalSpending(_currentSpending!) - _getTotalSpending(_optimizedSpending!) > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF10B981),
                              Color(0xFF059669),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.savings_outlined,
                              color: Colors.white,
                              size: 40,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Сохраните экономию!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Создайте вклад в Best ADOFF Bank на сумму экономии: ${(_getTotalSpending(_currentSpending!) - _getTotalSpending(_optimizedSpending!)).toStringAsFixed(0)} ₽',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isCreatingDeposit ? null : _createDepositInBABank,
                                icon: _isCreatingDeposit
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : const Icon(Icons.add_card, size: 24),
                                label: Text(_isCreatingDeposit ? 'Создание вклада...' : 'Создать вклад одной кнопкой'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF059669),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Create virtual accounts button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _createVirtualAccountsFromOptimization,
                        icon: const Icon(Icons.account_balance_wallet),
                        label: const Text('Создать виртуальные счета'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: const Color(0xFF6366F1),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.darkBlue,
      ),
    );
  }

  Widget _buildSpendingChart(Map<String, double> spending, double income, String type) {
    final totalSpending = _getTotalSpending(spending);
    final nonZeroSpending = spending.entries.where((e) => e.value > 0).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Income and Total Spending
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Доход', '${income.toStringAsFixed(0)} ₽', Colors.green),
              _buildStatItem('Расходы', '${totalSpending.toStringAsFixed(0)} ₽', Colors.orange),
            ],
          ),
          const SizedBox(height: 20),

          // Pie Chart
          if (nonZeroSpending.isNotEmpty)
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: _buildPieChartSections(spending),
                  centerSpaceRadius: 50,
                  sectionsSpace: 2,
                ),
              ),
            ),

          const SizedBox(height: 20),

          // Legend
          _buildChartLegend(spending),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieChartSections(Map<String, double> spending) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    final totalSpending = _getTotalSpending(spending);
    final nonZeroSpending = spending.entries.where((e) => e.value > 0).toList();

    return List.generate(nonZeroSpending.length, (index) {
      final entry = nonZeroSpending[index];
      final percentage = (entry.value / totalSpending) * 100;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  Widget _buildChartLegend(Map<String, double> spending) {
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.pink,
      Colors.amber,
    ];

    final nonZeroSpending = spending.entries.where((e) => e.value > 0).toList();

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: List.generate(nonZeroSpending.length, (index) {
        final entry = nonZeroSpending[index];
        final russianCategory = _optimizationService.mapEnglishToRussian(entry.key);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: colors[index % colors.length],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$russianCategory: ${entry.value.toStringAsFixed(0)} ₽',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildBalanceCard(String title, double balance) {
    final isPositive = balance >= 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive ? Colors.green : Colors.red,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isPositive ? Colors.green[900] : Colors.red[900],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${balance.toStringAsFixed(2)} ₽',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isPositive ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard() {
    if (_currentSpending == null || _optimizedSpending == null) {
      return const SizedBox.shrink();
    }

    final currentTotal = _getTotalSpending(_currentSpending!);
    final optimizedTotal = _getTotalSpending(_optimizedSpending!);
    final savings = currentTotal - optimizedTotal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.1),
            AppTheme.accentBlue.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.compare_arrows,
            color: AppTheme.primaryBlue,
            size: 32,
          ),
          const SizedBox(height: 12),
          const Text(
            'Сравнение',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkBlue,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildComparisonItem('Текущие', currentTotal, Colors.orange),
              _buildComparisonItem('Рекомендуемые', optimizedTotal, Colors.blue),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: savings >= 0 ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  savings >= 0 ? Icons.trending_down : Icons.trending_up,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  savings >= 0
                      ? 'Экономия: ${savings.toStringAsFixed(0)} ₽'
                      : 'Увеличение: ${(-savings).toStringAsFixed(0)} ₽',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)} ₽',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  double _getTotalSpending(Map<String, double> spending) {
    return spending.values.fold(0.0, (sum, value) => sum + value);
  }
}
