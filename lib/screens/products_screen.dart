import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/product_provider.dart';
import '../providers/account_provider.dart';
import '../services/auth_service.dart';
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Нет доступных продуктов'),
            if (type == 'card') ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _showIssueCardDialog(context),
                icon: const Icon(Icons.add_card),
                label: const Text('Выпустить карту'),
              ),
            ],
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: type == 'card' ? 180 : 110, // Extra space for card button
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
        ),
        if (type == 'card')
          Positioned(
            left: 16,
            right: 16,
            bottom: 110,
            child: Container(
              decoration: AppTheme.gradientButtonDecoration(),
              child: ElevatedButton.icon(
                onPressed: () => _showIssueCardDialog(context),
                icon: const Icon(Icons.add_card),
                label: const Text('Выпустить карту на существующий счет'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _showIssueCardDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _IssueCardDialog(),
    );
  }

  void _showProductDialog(BuildContext context, product) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, AppTheme.iceBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      product.productName.toLowerCase().contains('вклад') ? Icons.savings_rounded :
                      product.productName.toLowerCase().contains('кредит') ? Icons.account_balance_wallet_rounded :
                      Icons.credit_card_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          ApiConfig.getBankName(product.bankCode),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: AppTheme.modernCardDecoration(borderRadius: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    if (product.interestRate != null || product.minAmount != null ||
                        product.maxAmount != null || product.termMonths != null) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                    ],
                    if (product.interestRate != null)
                      _buildDetailRow(Icons.percent_rounded, 'Ставка', '${product.interestRate}%'),
                    if (product.minAmount != null)
                      _buildDetailRow(Icons.arrow_downward_rounded, 'Мин. сумма', product.minAmount),
                    if (product.maxAmount != null)
                      _buildDetailRow(Icons.arrow_upward_rounded, 'Макс. сумма', product.maxAmount),
                    if (product.termMonths != null)
                      _buildDetailRow(Icons.calendar_month_rounded, 'Срок', '${product.termMonths} мес.'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Закрыть',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: AppTheme.gradientButtonDecoration(),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _openProduct(context, product);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Оформить',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryBlue),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
            ),
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
        AppTheme.warningSnackBar('Нет доступных счетов'),
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
  String? _selectedAccountCompositeKey;  // Changed to composite key (bankCode:accountId)
  bool _isProcessing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter accounts to only show accounts from the same bank as the product
    final sameBankAccounts = widget.accounts.where((account) {
      return account.bankCode == widget.product.bankCode;
    }).toList();

    // Get unique accounts by composite key (bankCode:accountId) - prevents collisions
    final uniqueAccounts = <String, dynamic>{};
    for (var account in sameBankAccounts) {
      final compositeKey = '${account.bankCode}:${account.accountId}';
      uniqueAccounts[compositeKey] = account;
    }
    final accountsList = uniqueAccounts.values.cast<dynamic>().toList();

    return AlertDialog(
      title: Text('Оформить ${widget.product.productName}'),
      content: accountsList.isEmpty
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_amber_rounded, size: 48, color: AppTheme.warningOrange),
                const SizedBox(height: 16),
                Text(
                  'У вас нет счетов в ${ApiConfig.getBankName(widget.product.bankCode)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Для открытия продукта необходим счет в этом же банке',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Сумма'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedAccountCompositeKey,
                  decoration: InputDecoration(
                    labelText: 'Счет списания (${ApiConfig.getBankName(widget.product.bankCode)})',
                  ),
                  isExpanded: true,
                  items: accountsList.map<DropdownMenuItem<String>>((account) {
                    final compositeKey = '${account.bankCode}:${account.accountId}';
                    return DropdownMenuItem<String>(
                      value: compositeKey,  // Use composite key as value
                      child: Text(
                        account.displayName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedAccountCompositeKey = value),
                ),
              ],
            ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        if (accountsList.isNotEmpty)
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
    if (amount == null || _selectedAccountCompositeKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.warningSnackBar('Заполните все поля'),
      );
      return;
    }

    // Parse composite key to get bankCode and accountId
    final parts = _selectedAccountCompositeKey!.split(':');
    final bankCode = parts[0];
    final accountId = parts[1];

    // Find the selected account using composite key
    final selectedAccount = widget.accounts.firstWhere(
      (acc) => acc.bankCode == bankCode && acc.accountId == accountId,
    );

    // Use identification if available, otherwise use accountId
    final sourceAccountIdentifier = selectedAccount.identification ?? accountId;

    debugPrint('[ProductsScreen] Opening product: ${widget.product.productName}');
    debugPrint('[ProductsScreen] Selected composite key: $_selectedAccountCompositeKey');
    debugPrint('[ProductsScreen] Selected accountId: $accountId');
    debugPrint('[ProductsScreen] Selected account identification: ${selectedAccount.identification}');
    debugPrint('[ProductsScreen] Source account identifier to use: $sourceAccountIdentifier');
    debugPrint('[ProductsScreen] Product bank: ${widget.product.bankCode}');
    debugPrint('[ProductsScreen] Account bank: ${selectedAccount.bankCode}');

    setState(() => _isProcessing = true);

    try {
      final provider = context.read<ProductProvider>();
      await provider.openProduct(
        product: widget.product,
        amount: amount,
        termMonths: widget.product.termMonths,
        sourceAccountId: sourceAccountIdentifier,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.successSnackBar('Продукт успешно оформлен!'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.errorSnackBar('Ошибка: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

// Issue Card Dialog
class _IssueCardDialog extends StatefulWidget {
  const _IssueCardDialog();

  @override
  State<_IssueCardDialog> createState() => _IssueCardDialogState();
}

class _IssueCardDialogState extends State<_IssueCardDialog> {
  String? _selectedAccountId;
  String? _selectedBank;
  String _cardType = 'debit';
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final accounts = accountProvider.accounts;

    // Get unique banks
    final banks = accounts.map((a) => a.bankCode).toSet().toList();

    return AlertDialog(
      title: const Text('Выпустить карту'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Выберите счет для привязки карты',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBank,
              decoration: const InputDecoration(labelText: 'Банк'),
              items: banks.map<DropdownMenuItem<String>>((bank) {
                return DropdownMenuItem<String>(
                  value: bank,
                  child: Text(ApiConfig.getBankName(bank)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBank = value;
                  _selectedAccountId = null; // Reset account selection
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedBank != null)
              DropdownButtonFormField<String>(
                value: _selectedAccountId,
                decoration: const InputDecoration(labelText: 'Счет'),
                items: accounts
                    .where((a) => a.bankCode == _selectedBank)
                    .map<DropdownMenuItem<String>>((account) {
                  return DropdownMenuItem<String>(
                    value: account.accountId,
                    child: Text(account.displayName),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedAccountId = value),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _cardType,
              decoration: const InputDecoration(labelText: 'Тип карты'),
              items: const [
                DropdownMenuItem(value: 'debit', child: Text('Дебетовая')),
                DropdownMenuItem(value: 'credit', child: Text('Кредитная')),
              ],
              onChanged: (value) => setState(() => _cardType = value!),
            ),
          ],
        ),
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
              : const Text('Выпустить'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_selectedAccountId == null || _selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.warningSnackBar('Выберите банк и счет'),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final authService = context.read<AuthService>();
      final accountProvider = context.read<AccountProvider>();
      final service = authService.getBankService(_selectedBank!);
      final consent = await authService.getProductConsent(_selectedBank!);

      // Find the selected account to get its identification
      final selectedAccount = accountProvider.accounts.firstWhere(
        (acc) => acc.accountId == _selectedAccountId,
      );

      // Use identification if available, otherwise use accountId
      final accountIdentifier = selectedAccount.identification ?? _selectedAccountId!;

      await service.issueCard(
        clientId: authService.clientId,
        accountId: accountIdentifier,
        cardType: _cardType,
        consentId: consent.consentId,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.successSnackBar('Карта успешно выпущена!'),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.errorSnackBar('Ошибка: $e'),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}