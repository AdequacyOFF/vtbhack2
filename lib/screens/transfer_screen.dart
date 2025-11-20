import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';
import '../providers/account_provider.dart';
import '../models/bank_account.dart';
import '../models/contact.dart';
import '../models/debt.dart';
import '../services/contacts_service.dart';
import '../services/debts_service.dart';
import '../services/auth_service.dart';
import '../config/app_theme.dart';

enum TransferType {
  ownAccounts,
  toContact,
  toNewRecipient,
}

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();
  final _recipientIdController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientAccountController = TextEditingController();

  BankAccount? _fromAccount;
  BankAccount? _toAccount;
  TransferType _transferType = TransferType.ownAccounts;
  Contact? _selectedContact;
  String? _selectedRecipientBank;
  bool _isDebt = false;
  DateTime? _returnDate;
  bool _saveAsContact = false;

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    _recipientIdController.dispose();
    _recipientNameController.dispose();
    _recipientAccountController.dispose();
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
                'Перевод',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),

              // Transfer Type Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Тип перевода',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<TransferType>(
                        segments: const [
                          ButtonSegment(
                            value: TransferType.ownAccounts,
                            label: Text('Свои счета'),
                            icon: Icon(Icons.account_balance_wallet),
                          ),
                          ButtonSegment(
                            value: TransferType.toContact,
                            label: Text('Контакт'),
                            icon: Icon(Icons.contacts),
                          ),
                          ButtonSegment(
                            value: TransferType.toNewRecipient,
                            label: Text('Новый'),
                            icon: Icon(Icons.person_add),
                          ),
                        ],
                        selected: {_transferType},
                        onSelectionChanged: (Set<TransferType> newSelection) {
                          setState(() {
                            _transferType = newSelection.first;
                            _toAccount = null;
                            _selectedContact = null;
                            _recipientIdController.clear();
                            _selectedRecipientBank = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

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

              // Recipient Section
              if (_transferType == TransferType.ownAccounts)
                _buildOwnAccountsRecipient(accounts, accountProvider)
              else if (_transferType == TransferType.toContact)
                _buildContactRecipient()
              else
                _buildNewRecipient(),

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

              const SizedBox(height: 16),

              // Comment
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _commentController,
                    decoration: const InputDecoration(
                      labelText: 'Комментарий (необязательно)',
                      prefixIcon: Icon(Icons.comment),
                      hintText: 'Назначение платежа',
                    ),
                    maxLength: 100,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Debt Checkbox
              Card(
                child: CheckboxListTile(
                  title: const Text('Это долг'),
                  subtitle: const Text('Установить напоминание о возврате'),
                  value: _isDebt,
                  onChanged: (value) {
                    setState(() {
                      _isDebt = value ?? false;
                      if (!_isDebt) {
                        _returnDate = null;
                      }
                    });
                  },
                  secondary: const Icon(Icons.calendar_month),
                ),
              ),

              // Return Date (only if debt)
              if (_isDebt) ...[
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event),
                    title: const Text('Дата возврата'),
                    subtitle: Text(
                      _returnDate != null
                          ? '${_returnDate!.day}.${_returnDate!.month}.${_returnDate!.year}'
                          : 'Не указана',
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _pickReturnDate,
                  ),
                ),
              ],

              // Save as contact option (only for new recipients)
              if (_transferType == TransferType.toNewRecipient) ...[
                const SizedBox(height: 16),
                Card(
                  child: CheckboxListTile(
                    title: const Text('Сохранить как контакт'),
                    subtitle: const Text('Добавить в список контактов'),
                    value: _saveAsContact,
                    onChanged: (value) {
                      setState(() {
                        _saveAsContact = value ?? false;
                      });
                    },
                    secondary: const Icon(Icons.person_add),
                  ),
                ),
              ],

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

  Widget _buildOwnAccountsRecipient(List<BankAccount> accounts, AccountProvider accountProvider) {
    return Card(
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
    );
  }

  Widget _buildContactRecipient() {
    final contactsService = ContactsService();

    return FutureBuilder<List<Contact>>(
      future: contactsService.loadContacts().then((_) => contactsService.getAllContacts()),
      builder: (context, snapshot) {
        final contacts = snapshot.data ?? [];

        if (contacts.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.contacts_outlined, size: 48, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Нет сохраненных контактов',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _transferType = TransferType.toNewRecipient;
                      });
                    },
                    child: const Text('Добавить новый контакт'),
                  ),
                ],
              ),
            ),
          );
        }

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Получатель из контактов'),
                const SizedBox(height: 12),
                DropdownButtonFormField<Contact>(
                  value: _selectedContact,
                  decoration: const InputDecoration(
                    hintText: 'Выберите контакт',
                    prefixIcon: Icon(Icons.person),
                  ),
                  items: contacts.map<DropdownMenuItem<Contact>>((contact) {
                    return DropdownMenuItem<Contact>(
                      value: contact,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(contact.displayName),
                          Text(
                            contact.description,
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedContact = value),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNewRecipient() {
    final banks = ['vbank', 'abank', 'sbank'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Данные получателя'),
            const SizedBox(height: 16),

            // Recipient Client ID
            TextField(
              controller: _recipientIdController,
              decoration: const InputDecoration(
                labelText: 'Client ID получателя',
                prefixIcon: Icon(Icons.badge),
                hintText: 'team201-1, team201-2, и т.д.',
              ),
            ),

            const SizedBox(height: 16),

            // Recipient Account ID
            TextField(
              controller: _recipientAccountController,
              decoration: const InputDecoration(
                labelText: 'Номер счета получателя',
                prefixIcon: Icon(Icons.account_box),
                hintText: '40817810...',
              ),
            ),

            const SizedBox(height: 16),

            // Recipient Name (for saving as contact)
            if (_saveAsContact)
              Column(
                children: [
                  TextField(
                    controller: _recipientNameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя контакта',
                      prefixIcon: Icon(Icons.person),
                      hintText: 'Например: Иван Иванов',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Bank Selection
            DropdownButtonFormField<String>(
              value: _selectedRecipientBank,
              decoration: const InputDecoration(
                labelText: 'Банк получателя',
                prefixIcon: Icon(Icons.account_balance),
              ),
              items: banks.map<DropdownMenuItem<String>>((bank) {
                return DropdownMenuItem<String>(
                  value: bank,
                  child: Text(bank.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedRecipientBank = value),
            ),

            const SizedBox(height: 8),
            const Text(
              '💡 Для межбанковских переводов выберите банк получателя',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReturnDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _returnDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Выберите дату возврата долга',
    );

    if (picked != null) {
      setState(() {
        _returnDate = picked;
      });
    }
  }

  Future<void> _performTransfer() async {
    final amount = double.tryParse(_amountController.text);

    if (_fromAccount == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все обязательные поля')),
      );
      return;
    }

    // Validate based on transfer type
    String? recipientAccountId;
    String? recipientBank;
    String? recipientClientId;
    String? recipientName;

    if (_transferType == TransferType.ownAccounts) {
      if (_toAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите счет получателя')),
        );
        return;
      }

      if (_fromAccount!.accountId == _toAccount!.accountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите разные счета')),
        );
        return;
      }

      recipientAccountId = _toAccount!.accountId;
      recipientBank = _toAccount!.bankCode;
    } else if (_transferType == TransferType.toContact) {
      if (_selectedContact == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Выберите контакт')),
        );
        return;
      }

      if (_selectedContact!.accountId == null || _selectedContact!.accountId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('У контакта не указан номер счета')),
        );
        return;
      }

      recipientClientId = _selectedContact!.clientId;
      recipientName = _selectedContact!.name;
      recipientBank = _selectedContact!.bankCode;
      recipientAccountId = _selectedContact!.accountId;
    } else {
      // New recipient
      if (_recipientIdController.text.trim().isEmpty ||
          _recipientAccountController.text.trim().isEmpty ||
          _selectedRecipientBank == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите Client ID, номер счета и банк получателя')),
        );
        return;
      }

      recipientClientId = _recipientIdController.text.trim();
      recipientAccountId = _recipientAccountController.text.trim();
      recipientBank = _selectedRecipientBank;

      if (_saveAsContact && _recipientNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите имя контакта')),
        );
        return;
      }

      recipientName = _saveAsContact ? _recipientNameController.text.trim() : recipientClientId;
    }

    // If debt is checked, validate return date
    if (_isDebt && _returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите дату возврата долга')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Подтверждение перевода'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Сумма: ${amount.toStringAsFixed(2)} ₽'),
            Text('Со счета: ${_fromAccount!.displayName}'),
            Text('Получатель: ${recipientName ?? recipientClientId ?? recipientAccountId}'),
            if (recipientBank != null) Text('Банк: ${recipientBank.toUpperCase()}'),
            if (_commentController.text.isNotEmpty)
              Text('Комментарий: ${_commentController.text}'),
            if (_isDebt) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_month, size: 16, color: AppTheme.warningOrange),
                        SizedBox(width: 4),
                        Text('Долг', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text('Дата возврата: ${_returnDate!.day}.${_returnDate!.month}.${_returnDate!.year}'),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Perform transfer
    final transferProvider = context.read<TransferProvider>();

    // For new recipients, we need to get their account first
    // This is simplified - in production you'd call an API to look up their account
    BankAccount? targetAccount = _toAccount;

    if (_transferType != TransferType.ownAccounts) {
      // Validate we have account ID
      if (recipientAccountId == null || recipientAccountId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Отсутствует номер счета получателя')),
          );
        }
        return;
      }

      // Create a temporary account object for the transfer
      targetAccount = BankAccount(
        accountId: recipientAccountId,
        bankCode: recipientBank!,
        status: 'Enabled',
        currency: 'RUB',
        accountType: 'current',
        accountSubType: 'CurrentAccount',
        openingDate: DateTime.now().toIso8601String(),
        name: recipientName ?? recipientClientId ?? 'Unknown',
        identification: recipientAccountId,
      );
    }

    final success = await transferProvider.transferMoney(
      fromAccount: _fromAccount!,
      toAccount: targetAccount!,
      amount: amount,
      comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
    );

    if (success && mounted) {
      // Save contact if requested
      if (_saveAsContact && _transferType == TransferType.toNewRecipient) {
        final contactsService = ContactsService();
        await contactsService.loadContacts();
        await contactsService.addContact(
          clientId: recipientClientId!,
          name: recipientName!,
          bankCode: recipientBank,
          accountId: recipientAccountId,
        );
      }

      // Save debt if requested
      if (_isDebt) {
        final debtsService = DebtsService();
        final authService = context.read<AuthService>();
        await debtsService.loadDebts();
        await debtsService.addDebt(
          contactId: recipientClientId ?? recipientAccountId ?? 'unknown',
          contactName: recipientName ?? recipientClientId ?? 'Unknown',
          contactClientId: recipientClientId ?? 'unknown',
          amount: amount,
          type: DebtType.owedToMe, // I lent money
          returnDate: _returnDate,
          comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Долг добавлен в список. Мы напомним о возврате!'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Перевод выполнен успешно!')),
        );

        // Clear form
        _amountController.clear();
        _commentController.clear();
        _recipientIdController.clear();
        _recipientNameController.clear();
        setState(() {
          _fromAccount = null;
          _toAccount = null;
          _selectedContact = null;
          _selectedRecipientBank = null;
          _isDebt = false;
          _returnDate = null;
          _saveAsContact = false;
        });

        // Refresh accounts
        context.read<AccountProvider>().fetchAllAccounts();
      }
    }
  }
}
