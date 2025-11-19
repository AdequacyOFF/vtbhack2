import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/account_provider.dart';
import '../config/app_theme.dart';
import '../config/api_config.dart';

class ProductsScreen extends StatelessWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Продукты',
            style: TextStyle(color: Colors.white), // Белый цвет текста
          ),
          backgroundColor: AppTheme.primaryBlue, // Цвет фона AppBar
          iconTheme: const IconThemeData(color: Colors.white), // Белый цвет иконок
          bottom: const TabBar(
            labelColor: Colors.white, // Белый цвет выбранной вкладки
            unselectedLabelColor: Colors.white70, // Светло-белый для невыбранных
            indicatorColor: Colors.white, // Белый цвет индикатора
            tabs: [
              Tab(text: 'Вклады'),
              Tab(text: 'Кредиты'),
              Tab(text: 'Карты'),
            ],
          ),
        ),
        body: Consumer<ProductProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            return TabBarView(
              children: [
                _ProductList(products: provider.deposits, type: 'deposit'),
                _ProductList(products: provider.loans, type: 'loan'),
                _ProductList(products: provider.cards, type: 'card'),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Остальной код без изменений...
class _ProductList extends StatelessWidget {
  final List products;
  final String type;

  const _ProductList({required this.products, required this.type});

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Center(child: Text('Нет доступных продуктов'));
    }

    return ListView.builder(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: 110, // Space for floating bottom bar
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
              child: Icon(
                type == 'deposit'
                    ? Icons.savings
                    : type == 'loan'
                    ? Icons.account_balance_wallet
                    : Icons.credit_card,
                color: AppTheme.primaryBlue,
              ),
            ),
            title: Text(product.productName),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.description),
                const SizedBox(height: 4),
                Text(
                  '${ApiConfig.getBankName(product.bankCode)} • ${product.interestRate ?? '0'}%',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _showProductDialog(context, product),
          ),
        );
      },
    );
  }

  void _showProductDialog(BuildContext context, product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.productName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Банк: ${ApiConfig.getBankName(product.bankCode)}'),
              const SizedBox(height: 8),
              Text('Описание: ${product.description}'),
              const SizedBox(height: 8),
              if (product.interestRate != null)
                Text('Ставка: ${product.interestRate}%'),
              if (product.minAmount != null)
                Text('Мин. сумма: ${product.minAmount}'),
              if (product.maxAmount != null)
                Text('Макс. сумма: ${product.maxAmount}'),
              if (product.termMonths != null)
                Text('Срок: ${product.termMonths} мес.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openProduct(context, product);
            },
            child: const Text('Оформить'),
          ),
        ],
      ),
    );
  }

  void _openProduct(BuildContext context, product) {
    final accountProvider = context.read<AccountProvider>();
    final accounts = accountProvider.accounts;

    if (accounts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нет доступных счетов')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _OpenProductDialog(product: product, accounts: accounts),
    );
  }
}

class _OpenProductDialog extends StatefulWidget {
  final product;
  final List accounts;

  const _OpenProductDialog({required this.product, required this.accounts});

  @override
  State<_OpenProductDialog> createState() => _OpenProductDialogState();
}

class _OpenProductDialogState extends State<_OpenProductDialog> {
  final _amountController = TextEditingController();
  String? _selectedAccountId;
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get unique accounts by accountId - ensure proper typing
    final uniqueAccounts = <String, dynamic>{};
    for (var account in widget.accounts) {
      uniqueAccounts[account.accountId] = account;
    }
    final accountsList = uniqueAccounts.values.cast<dynamic>().toList();

    return AlertDialog(
      title: Text('Оформить ${widget.product.productName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(labelText: 'Сумма'),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedAccountId,
            decoration: const InputDecoration(labelText: 'Счет списания'),
            items: accountsList.map<DropdownMenuItem<String>>((account) {
              return DropdownMenuItem<String>(
                value: account.accountId,
                child: Text(account.displayName),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedAccountId = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        ElevatedButton(
          onPressed: _isProcessing ? null : _submit,
          child: _isProcessing
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Оформить'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || _selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final provider = context.read<ProductProvider>();
      await provider.openProduct(
        product: widget.product,
        amount: amount,
        termMonths: widget.product.termMonths,
        sourceAccountId: _selectedAccountId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Продукт успешно оформлен!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}