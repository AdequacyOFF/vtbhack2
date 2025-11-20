import 'package:flutter/material.dart';
import '../models/debt.dart';
import '../services/debts_service.dart';
import '../config/app_theme.dart';

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key});

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> with SingleTickerProviderStateMixin {
  final DebtsService _debtsService = DebtsService();
  List<Debt> _myDebts = [];
  List<Debt> _debtsToMe = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDebts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDebts() async {
    setState(() => _isLoading = true);
    await _debtsService.loadDebts();
    setState(() {
      _myDebts = _debtsService.getMyDebts();
      _debtsToMe = _debtsService.getDebtsToMe();
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final totalIOwe = _debtsService.getTotalIOwe();
    final totalOwedToMe = _debtsService.getTotalOwedToMe();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Долги'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.arrow_upward),
              text: 'Я должен (${_myDebts.length})',
            ),
            Tab(
              icon: const Icon(Icons.arrow_downward),
              text: 'Мне должны (${_debtsToMe.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Summary Cards
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Я должен',
                    amount: totalIOwe,
                    color: AppTheme.errorRed,
                    icon: Icons.arrow_upward,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Мне должны',
                    amount: totalOwedToMe,
                    color: AppTheme.successGreen,
                    icon: Icons.arrow_downward,
                  ),
                ),
              ],
            ),
          ),

          // Tabs Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDebtsList(_myDebts, DebtType.iOwe),
                      _buildDebtsList(_debtsToMe, DebtType.owedToMe),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${amount.toStringAsFixed(2)} ₽',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtsList(List<Debt> debts, DebtType type) {
    if (debts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == DebtType.iOwe
                  ? Icons.check_circle_outline
                  : Icons.payments_outlined,
              size: 80,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              type == DebtType.iOwe
                  ? 'Нет активных долгов'
                  : 'Никто вам не должен',
              style: const TextStyle(
                fontSize: 18,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              type == DebtType.iOwe
                  ? 'Вы молодец!'
                  : 'Сделайте перевод с отметкой "Это долг"',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: debts.length,
      itemBuilder: (context, index) {
        final debt = debts[index];
        return _buildDebtCard(debt);
      },
    );
  }

  Widget _buildDebtCard(Debt debt) {
    final isOverdue = debt.isOverdue;
    final isUpcoming = debt.daysUntilReturn != null &&
                       debt.daysUntilReturn! <= 3 &&
                       debt.daysUntilReturn! > 0;

    Color statusColor = AppTheme.textSecondary;
    if (isOverdue) {
      statusColor = AppTheme.errorRed;
    } else if (isUpcoming) {
      statusColor = AppTheme.warningOrange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(
            debt.type == DebtType.iOwe
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            color: statusColor,
          ),
        ),
        title: Text(
          debt.contactName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(debt.formattedAmount),
            if (debt.returnDate != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    isOverdue
                        ? Icons.warning
                        : Icons.calendar_today,
                    size: 14,
                    color: statusColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    debt.statusDescription,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: isOverdue || isUpcoming
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
            if (debt.comment != null && debt.comment!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                '💬 ${debt.comment}',
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'mark_returned') {
              _markAsReturned(debt);
            } else if (value == 'delete') {
              _showDeleteConfirmation(debt);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'mark_returned',
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: AppTheme.successGreen),
                  SizedBox(width: 8),
                  Text('Отметить как возвращенный'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: AppTheme.errorRed),
                  SizedBox(width: 8),
                  Text('Удалить', style: TextStyle(color: AppTheme.errorRed)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsReturned(Debt debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Отметить как возвращенный?'),
        content: Text(
          'Долг от "${debt.contactName}" на сумму ${debt.formattedAmount} будет отмечен как возвращенный.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
            ),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _debtsService.markAsReturned(debt.id);
      _loadDebts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Долг отмечен как возвращенный'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(Debt debt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить долг?'),
        content: Text('Удалить запись о долге от "${debt.contactName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _debtsService.deleteDebt(debt.id);
      _loadDebts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Долг удален')),
        );
      }
    }
  }
}
