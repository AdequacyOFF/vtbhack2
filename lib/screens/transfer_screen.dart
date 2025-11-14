import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';
import '../providers/account_provider.dart';
import '../models/bank_account.dart';
import '../config/app_theme.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _amountController = TextEditingController();
  BankAccount? _fromAccount;
  BankAccount? _toAccount;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer2<AccountProvider, TransferProvider>(
        builder: (context, accountProvider, transferProvider, child) {
          // Get unique accounts by accountId
          final uniqueAccountsMap = <String, BankAccount>{};
          for (var account in accountProvider.accounts) {
            uniqueAccountsMap[account.accountId] = account;
          }
          final accounts = uniqueAccountsMap.values.toList();

          return ListView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 110, // Space for floating bottom bar
            ),
            children: [
              const SizedBox(height: 16),
              Text(
                'Перевод между счетами',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),

              // From Account
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Счет списания'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<BankAccount>(
                        value: _fromAccount,
                        decoration: const InputDecoration(
                          hintText: 'Выберите счет',
                          prefixIcon: Icon(Icons.account_balance_wallet),
                        ),
                        items: accounts.map<DropdownMenuItem<BankAccount>>((account) {
                          final balance = accountProvider.getBalance(account);
                          return DropdownMenuItem<BankAccount>(
                            value: account,
                            child: Text('${account.displayName} (${balance.toStringAsFixed(2)} ₽)'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _fromAccount = value),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // To Account
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Счет зачисления'),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<BankAccount>(
                        value: _toAccount,
                        decoration: const InputDecoration(
                          hintText: 'Выберите счет',
                          prefixIcon: Icon(Icons.account_balance),
                        ),
                        items: accounts.map<DropdownMenuItem<BankAccount>>((account) {
                          final balance = accountProvider.getBalance(account);
                          return DropdownMenuItem<BankAccount>(
                            value: account,
                            child: Text('${account.displayName} (${balance.toStringAsFixed(2)} ₽)'),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _toAccount = value),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Amount
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Сумма',
                      prefixIcon: Icon(Icons.attach_money),
                      suffix: Text('₽'),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Transfer Button
              ElevatedButton(
                onPressed: transferProvider.isProcessing ? null : _performTransfer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: transferProvider.isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Перевести', style: TextStyle(fontSize: 18)),
              ),

              if (transferProvider.error != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: AppTheme.errorRed.withOpacity(0.1),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.error, color: AppTheme.errorRed),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            transferProvider.error!,
                            style: const TextStyle(color: AppTheme.errorRed),
                          ),
                        ),
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

  Future<void> _performTransfer() async {
    final amount = double.tryParse(_amountController.text);

    if (_fromAccount == null || _toAccount == null || amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    if (_fromAccount!.accountId == _toAccount!.accountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите разные счета')),
      );
      return;
    }

    final transferProvider = context.read<TransferProvider>();
    final success = await transferProvider.transferMoney(
      fromAccount: _fromAccount!,
      toAccount: _toAccount!,
      amount: amount,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Перевод выполнен успешно!')),
      );

      // Clear form
      _amountController.clear();
      setState(() {
        _fromAccount = null;
        _toAccount = null;
      });

      // Refresh accounts
      context.read<AccountProvider>().fetchAllAccounts();
    }
  }
}
