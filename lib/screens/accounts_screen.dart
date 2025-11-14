import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/bank_account.dart';
import '../providers/account_provider.dart';
import '../config/app_theme.dart';

class AccountsScreen extends StatefulWidget {
  final BankAccount account;

  const AccountsScreen({super.key, required this.account});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AccountProvider>().fetchTransactionsForAccount(widget.account.accountId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account.displayName),
      ),
      body: Consumer<AccountProvider>(
        builder: (context, provider, child) {
          final balance = provider.getBalance(widget.account);
          final transactions = provider.transactions[widget.account.accountId] ?? [];

          return ListView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 110, // Space for floating bottom bar
            ),
            children: [
              // Balance Card
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Доступный баланс',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${balance.toStringAsFixed(2)} ${widget.account.currency}',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.account.identification ?? widget.account.accountId,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Transactions
              if (transactions.isNotEmpty) ...[
                Text(
                  'Операции',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ...transactions.map((tx) {
                  final date = DateTime.tryParse(tx.bookingDateTime);
                  final dateStr = date != null ? DateFormat('dd MMM yyyy').format(date) : '';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: tx.isCredit
                            ? AppTheme.successGreen.withOpacity(0.1)
                            : AppTheme.errorRed.withOpacity(0.1),
                        child: Icon(
                          tx.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                          color: tx.isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                        ),
                      ),
                      title: Text(tx.transactionInformation ?? 'Транзакция'),
                      subtitle: Text(dateStr),
                      trailing: Text(
                        '${tx.isCredit ? '+' : '-'}${tx.amount} ₽',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: tx.isCredit ? AppTheme.successGreen : AppTheme.errorRed,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ] else ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 48, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет транзакций'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
