import 'dart:ui';
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
  State<ExpensesOptimizationScreen> createState() =>
      _ExpensesOptimizationScreenState();
}

class _ExpensesOptimizationScreenState
    extends State<ExpensesOptimizationScreen> {
  final _optimizationService = ExpensesOptimizationService();
  final _wishesController = TextEditingController();

  Map<String, double>? _currentSpending;
  Map<String, double>? _optimizedSpending;
  double _currentIncome = 0.0;
  double _optimizedIncome = 0.0;
  String? _aiComment;
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
      _currentSpending =
          _optimizationService.collectMonthlySpending(transactions);
      _currentIncome =
          _optimizationService.calculateMonthlyIncome(transactions);
    });
  }

  Future<void> _getOptimizationAdvice() async {
    if (_wishesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
          Text('Введите ваши пожелания по распределению финансов'),
        ),
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
        _aiComment = result['comment'] as String?;
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
        final russianCategory =
        _optimizationService.mapEnglishToRussian(entry.key);
        final amount = entry.value;

        if (amount <= 0) continue;

        final existingAccount =
        virtualAccountProvider.getAccountByCategory(russianCategory);
        if (existingAccount != null) {
          await virtualAccountProvider.updateVirtualAccount(
            accountId: existingAccount.id,
            newAllocatedAmount: amount,
          );
        } else {
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
            content: Text(
                'Создано/обновлено $createdCount виртуальных счетов'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Ошибка при создании счетов: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _createDepositInBABank() async {
    if (_currentSpending == null || _optimizedSpending == null) return;

    final savings = _getTotalSpending(_currentSpending!) -
        _getTotalSpending(_optimizedSpending!);

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

      if (productProvider.productsByBank.isEmpty) {
        await productProvider.fetchAllProducts();
      }

      final babankProducts =
          productProvider.productsByBank['babank'] ?? [];
      final babankDeposits =
      babankProducts.where((p) => p.isDeposit).toList();

      if (babankDeposits.isEmpty) {
        throw Exception('Нет доступных вкладов в Best ADOFF Bank');
      }

      final validDeposits = babankDeposits.where((p) {
        final minAmount = p.minAmountValue;
        final maxAmount = p.maxAmountValue;
        if (minAmount != null && savings < minAmount) return false;
        if (maxAmount != null && savings > maxAmount) return false;
        return true;
      }).toList();

      if (validDeposits.isEmpty) {
        throw Exception(
          'Сумма ${savings.toStringAsFixed(2)} ₽ не подходит для доступных вкладов',
        );
      }

      validDeposits.sort((a, b) {
        final rateA = a.interestRateValue ?? 0;
        final rateB = b.interestRateValue ?? 0;
        return rateB.compareTo(rateA);
      });

      final bestDeposit = validDeposits.first;

      final accountProvider = context.read<AccountProvider>();
      final accounts = accountProvider.accounts;

      final babankAccounts =
      accounts.where((acc) => acc.bankCode == 'babank').toList();

      if (babankAccounts.isEmpty) {
        throw Exception(
          'У вас нет счетов в Best ADOFF Bank. Создайте счет для открытия вклада.',
        );
      }

      String? sourceAccountId;
      for (final account in babankAccounts) {
        final balance = accountProvider.getBalance(account);
        if (balance >= savings) {
          // CRITICAL: Use identification field for API calls, not accountId
          sourceAccountId = account.identification ?? account.accountId;
          break;
        }
      }

      if (sourceAccountId == null) {
        final totalBabankBalance = babankAccounts.fold<double>(
          0.0,
              (sum, acc) => sum + accountProvider.getBalance(acc),
        );

        throw Exception(
          'Недостаточно средств на счетах Best ADOFF Bank.\n'
              'Необходимо: ${savings.toStringAsFixed(2)} ₽\n'
              'Доступно: ${totalBabankBalance.toStringAsFixed(2)} ₽\n'
              'Пополните счет или переведите средства из других банков.',
        );
      }

      await productProvider.openProduct(
        product: bestDeposit,
        amount: savings,
        termMonths: 12,
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
            content:
            Text('Ошибка при создании вклада: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  PreferredSizeWidget _buildGlassAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'Оптимизация расходов',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            backgroundColor: AppTheme.darkBlue.withValues(alpha: 0.9),
            elevation: 0,
            centerTitle: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSpending = _currentSpending;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildGlassAppBar(context),
      body: currentSpending == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroCard(),
            const SizedBox(height: 18),

            _buildSectionTitle('Ваши расходы за последние 30 дней'),
            const SizedBox(height: 12),
            _buildSpendingChart(
              currentSpending,
              _currentIncome,
              'current',
            ),
            const SizedBox(height: 8),
            _buildBalanceCard(
              'Баланс за последние 30 дней',
              _currentIncome -
                  _getTotalSpending(currentSpending),
            ),

            const SizedBox(height: 26),
            _buildSectionTitle('Ваши пожелания'),
            const SizedBox(height: 10),
            _buildWishesField(),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                _isLoading ? null : _getOptimizationAdvice,
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _isLoading
                      ? 'Получение рекомендаций...'
                      : 'Получить рекомендации',
                ),
                style: ElevatedButton.styleFrom(
                  padding:
                  const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),

            if (_hasOptimization && _optimizedSpending != null) ...[
              const SizedBox(height: 28),
              _buildSectionTitle('Рекомендуемые расходы'),
              const SizedBox(height: 12),
              _buildSpendingChart(
                _optimizedSpending!,
                _optimizedIncome,
                'optimized',
              ),
              const SizedBox(height: 8),
              _buildBalanceCard(
                'Прогнозируемый баланс',
                _optimizedIncome -
                    _getTotalSpending(_optimizedSpending!),
              ),
              const SizedBox(height: 16),

              if (_aiComment != null && _aiComment!.isNotEmpty)
                _buildAICommentCard(),
              if (_aiComment != null && _aiComment!.isNotEmpty)
                const SizedBox(height: 16),

              _buildComparisonCard(),
              const SizedBox(height: 20),

              if (_getTotalSpending(currentSpending) -
                  _getTotalSpending(_optimizedSpending!) >
                  0)
                ...[
                  _buildDepositCta(currentSpending),
                  const SizedBox(height: 14),
                ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                  _createVirtualAccountsFromOptimization,
                  icon: const Icon(
                    Icons.account_balance_wallet_rounded,
                  ),
                  label: const Text(
                      'Создать виртуальные счета по категориям'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                    ),
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final totalSpending = _currentSpending != null
        ? _getTotalSpending(_currentSpending!)
        : 0.0;
    final freeMoney = _currentIncome - totalSpending;

    double? savings;
    if (_currentSpending != null && _optimizedSpending != null) {
      savings = _getTotalSpending(_currentSpending!) -
          _getTotalSpending(_optimizedSpending!);
    }

    return Container(
      decoration: AppTheme.modernCardDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: 24,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'ИИ поможет сделать ваши траты умнее',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Мы смотрим на последние операции и помогаем распределить деньги так, '
                  'чтобы быстрее идти к целям и меньше тратить на лишнее.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildHeroStat(
                  label: 'Доход за 30 дней',
                  value: '${_currentIncome.toStringAsFixed(0)} ₽',
                  icon: Icons.trending_up_rounded,
                ),
                const SizedBox(width: 10),
                _buildHeroStat(
                  label: 'Расходы',
                  value: '${totalSpending.toStringAsFixed(0)} ₽',
                  icon: Icons.trending_down_rounded,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildHeroChip(
                  icon: freeMoney >= 0
                      ? Icons.savings_rounded
                      : Icons.warning_rounded,
                  label: freeMoney >= 0
                      ? 'Свободные деньги: ${freeMoney.toStringAsFixed(0)} ₽'
                      : 'Перерасход: ${(-freeMoney).toStringAsFixed(0)} ₽',
                ),
                const SizedBox(width: 8),
                if (savings != null && savings > 0)
                  _buildHeroChip(
                    icon: Icons.auto_awesome_rounded,
                    label:
                    'Потенциальная экономия: ${savings.toStringAsFixed(0)} ₽',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withValues(alpha: 0.16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.18),
              ),
              child: Icon(
                icon,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroChip({required IconData icon, required String label}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: 0.18),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.menu_rounded,
            size: 14,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWishesField() {
    return Container(
      decoration: AppTheme.glassDecoration(
        color: AppTheme.primaryBlue,
        opacity: 0.06,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Расскажите, чего вы хотите',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Например: накопить на отпуск, уменьшить траты на доставку еды, '
                      'увеличить вклад и т.д.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _wishesController,
                  maxLines: 4,
                  minLines: 2,
                  keyboardType: TextInputType.multiline,
                  enableSuggestions: true,
                  autocorrect: true,
                  enableIMEPersonalizedLearning: true,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    hintText:
                    'Хочу откладывать 20% дохода и меньше тратить на развлечения...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue
                            .withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue
                            .withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(14)),
                      borderSide: BorderSide(
                        color: AppTheme.primaryBlue,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpendingChart(
      Map<String, double> spending,
      double income,
      String type,
      ) {
    final totalSpending = _getTotalSpending(spending);
    final nonZeroSpending =
    spending.entries.where((e) => e.value > 0).toList();
    final isCurrent = type == 'current';

    return Container(
      decoration: AppTheme.glassDecoration(
        color: AppTheme.primaryBlue,
        opacity: 0.06,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: (isCurrent
                            ? Colors.orange
                            : AppTheme.primaryBlue)
                            .withValues(alpha: 0.12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isCurrent
                                ? Icons.history_rounded
                                : Icons.auto_awesome_rounded,
                            size: 16,
                            color: isCurrent
                                ? Colors.orange
                                : AppTheme.primaryBlue,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isCurrent
                                ? 'Текущая картина'
                                : 'Рекомендации ИИ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isCurrent
                                  ? Colors.orange[900]
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Категорий: ${nonZeroSpending.length}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      'Доход',
                      '${income.toStringAsFixed(0)} ₽',
                      Colors.green,
                    ),
                    _buildStatItem(
                      'Расходы',
                      '${totalSpending.toStringAsFixed(0)} ₽',
                      Colors.orange,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (nonZeroSpending.isNotEmpty)
                  SizedBox(
                    height: 190,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieChartSections(spending),
                        centerSpaceRadius: 46,
                        sectionsSpace: 2,
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Пока нет трат по категориям',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 14),
                _buildChartLegend(spending),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  List<PieChartSectionData> _buildPieChartSections(
      Map<String, double> spending,
      ) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF3B82F6),
      const Color(0xFF22C55E),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
    ];

    final totalSpending = _getTotalSpending(spending);
    final nonZeroSpending =
    spending.entries.where((e) => e.value > 0).toList();

    if (totalSpending == 0) return [];

    return List.generate(nonZeroSpending.length, (index) {
      final entry = nonZeroSpending[index];
      final percentage = (entry.value / totalSpending) * 100;

      return PieChartSectionData(
        color: colors[index % colors.length],
        value: entry.value,
        title: '${percentage.toStringAsFixed(1)}%',
        radius: 60,
        titleStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    });
  }

  Widget _buildChartLegend(Map<String, double> spending) {
    final colors = [
      const Color(0xFF6366F1),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
      const Color(0xFFEC4899),
      const Color(0xFF3B82F6),
      const Color(0xFF22C55E),
      const Color(0xFF8B5CF6),
      const Color(0xFFEF4444),
    ];

    final nonZeroSpending =
    spending.entries.where((e) => e.value > 0).toList();

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: List.generate(nonZeroSpending.length, (index) {
        final entry = nonZeroSpending[index];
        final russianCategory =
        _optimizationService.mapEnglishToRussian(entry.key);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: Colors.white,
            border: Border.all(
              color: Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colors[index % colors.length],
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$russianCategory: ${entry.value.toStringAsFixed(0)} ₽',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildBalanceCard(String title, double balance) {
    final isPositive = balance >= 0;

    return Container(
      margin: const EdgeInsets.only(top: 2),
      decoration: AppTheme.glassDecoration(
        color: isPositive ? Colors.green : Colors.red,
        opacity: 0.06,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (isPositive ? Colors.green : Colors.red)
                        .withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    isPositive
                        ? Icons.savings_rounded
                        : Icons.priority_high_rounded,
                    color: isPositive ? Colors.green : Colors.red,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPositive
                          ? Colors.green[900]
                          : Colors.red[900],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${balance.toStringAsFixed(2)} ₽',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAICommentCard() {
    if (_aiComment == null || _aiComment!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: AppTheme.glassDecoration(
        color: AppTheme.primaryBlue,
        opacity: 0.06,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Theme(
            data:
            Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: const Icon(
                Icons.psychology_rounded,
                color: AppTheme.primaryBlue,
                size: 26,
              ),
              title: const Text(
                'Обоснование нейросети',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.darkBlue,
                ),
              ),
              subtitle: const Text(
                'Нажмите, чтобы прочитать подробное объяснение',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              tilePadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue
                        .withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _aiComment!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.darkBlue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryBlue.withValues(alpha: 0.08),
            AppTheme.accentBlue.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.primaryBlue.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.compare_arrows_rounded,
            color: AppTheme.primaryBlue,
            size: 30,
          ),
          const SizedBox(height: 8),
          const Text(
            'Сравнение до и после',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.darkBlue,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildComparisonItem(
                'Текущие расходы',
                currentTotal,
                Colors.orange,
              ),
              _buildComparisonItem(
                'Рекомендуемые',
                optimizedTotal,
                AppTheme.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: savings >= 0 ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  savings >= 0
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  savings >= 0
                      ? 'Экономия: ${savings.toStringAsFixed(0)} ₽'
                      : 'Увеличение: ${(-savings).toStringAsFixed(0)} ₽',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonItem(
      String label,
      double value,
      Color color,
      ) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)} ₽',
          style: TextStyle(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildDepositCta(Map<String, double> currentSpending) {
    final savings =
        _getTotalSpending(currentSpending) -
            _getTotalSpending(_optimizedSpending!);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF10B981),
            Color(0xFF059669),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.savings_outlined,
            color: Colors.white,
            size: 36,
          ),
          const SizedBox(height: 10),
          const Text(
            'Сохраните экономию на будущее',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Мы рассчитали, что можно отложить примерно '
                '${savings.toStringAsFixed(0)} ₽. Откройте вклад в Best ADOFF Bank в один клик.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
              _isCreatingDeposit ? null : _createDepositInBABank,
              icon: _isCreatingDeposit
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                  AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.add_card_rounded, size: 22),
              label: Text(
                _isCreatingDeposit
                    ? 'Создание вклада...'
                    : 'Создать вклад одной кнопкой',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF059669),
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _getTotalSpending(Map<String, double> spending) {
    return spending.values.fold(0.0, (sum, value) => sum + value);
  }
}
