import 'dart:ui';
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
import '../config/api_config.dart';

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
              'Перевод',
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
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: _buildGlassAppBar(context),
      body: Consumer2<AccountProvider, TransferProvider>(
        builder: (context, accountProvider, transferProvider, child) {
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
              bottom: 110,
            ),
            children: [
              _buildMainCard(accounts, accountProvider),
              const SizedBox(height: 16),
              _buildGlassSection(
                child: TextField(
                  controller: _commentController,
                  decoration: _inputDecoration(
                    label: 'Комментарий (необязательно)',
                    prefixIcon: Icons.comment_rounded,
                    hint: 'Назначение платежа',
                  ),
                  maxLength: 100,
                ),
              ),
              if (_transferType != TransferType.ownAccounts) ...[
                const SizedBox(height: 14),
                _buildGlassSection(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Это долг',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Мы напомним о возврате в выбранный день',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    value: _isDebt,
                    onChanged: (value) {
                      setState(() {
                        _isDebt = value ?? false;
                        if (!_isDebt) {
                          _returnDate = null;
                        }
                      });
                    },
                    secondary: const Icon(Icons.calendar_month_rounded),
                  ),
                ),
              ],
              if (_isDebt) ...[
                const SizedBox(height: 10),
                _buildGlassSection(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.event_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    title: const Text(
                      'Дата возврата',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      _returnDate != null
                          ? '${_returnDate!.day}.${_returnDate!.month}.${_returnDate!.year}'
                          : 'Не указана',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    onTap: _pickReturnDate,
                  ),
                ),
              ],
              if (_transferType == TransferType.toNewRecipient) ...[
                const SizedBox(height: 14),
                _buildGlassSection(
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Сохранить как контакт',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Добавить получателя в список контактов',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    value: _saveAsContact,
                    onChanged: (value) {
                      setState(() {
                        _saveAsContact = value ?? false;
                      });
                    },
                    secondary: const Icon(Icons.person_add_alt_1_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                  transferProvider.isProcessing ? null : _performTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
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
                      : const Text(
                    'Перевести',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (transferProvider.error != null) ...[
                const SizedBox(height: 14),
                _buildGlassSection(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.errorRed,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          transferProvider.error!,
                          style: const TextStyle(
                            color: AppTheme.errorRed,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildMainCard(
      List<BankAccount> accounts, AccountProvider accountProvider) {
    final hasFrom = _fromAccount != null;
    final hasTo = _transferType == TransferType.ownAccounts
        ? _toAccount != null
        : _transferType == TransferType.toContact
        ? _selectedContact != null
        : _recipientAccountController.text.trim().isNotEmpty ||
        _recipientIdController.text.trim().isNotEmpty;
    final hasAmount = _amountController.text.trim().isNotEmpty;
    final contactsService = ContactsService();
    final banks = ['vbank', 'abank', 'sbank'];

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
                    Icons.swap_horiz_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Откуда → Куда → Сумма',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Все основные параметры в одном месте',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildStepChip(
                  index: 1,
                  label: 'Откуда',
                  active: !hasFrom || (!hasTo && !hasAmount),
                  done: hasFrom,
                ),
                const SizedBox(width: 12),
                _buildStepChip(
                  index: 2,
                  label: 'Куда',
                  active: hasFrom && !hasTo,
                  done: hasTo,
                ),
                const SizedBox(width: 12),
                _buildStepChip(
                  index: 3,
                  label: 'Сумма',
                  active: hasFrom && hasTo && !hasAmount,
                  done: hasAmount,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Откуда',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                return DropdownButtonFormField<BankAccount>(
                  value: _fromAccount,
                  isExpanded: true,
                  isDense: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textPrimary,
                  ),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  decoration: _inputDecoration(
                    hint: 'Счёт списания',
                    prefixIcon: Icons.account_balance_wallet_rounded,
                  ),
                  items: accounts
                      .map<DropdownMenuItem<BankAccount>>((account) {
                    final balance = accountProvider.getBalance(account);
                    return DropdownMenuItem<BankAccount>(
                      value: account,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: constraints.maxWidth - 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${account.displayName} • ${ApiConfig.getBankName(account.bankCode)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                                height: 1.0,
                              ),
                            ),
                            Text(
                              '${balance.toStringAsFixed(2)} ${account.currency}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _fromAccount = value),
                );
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Куда',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: SegmentedButton<TransferType>(
                segments: [
                  ButtonSegment<TransferType>(
                    value: TransferType.ownAccounts,
                    icon: const Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 18,
                    ),
                    label: SizedBox(
                      width: 70,
                      child: Text(
                        'Свои счета',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ButtonSegment<TransferType>(
                    value: TransferType.toContact,
                    icon: const Icon(
                      Icons.contacts_rounded,
                      size: 18,
                    ),
                    label: SizedBox(
                      width: 70,
                      child: Text(
                        'Контакт',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  ButtonSegment<TransferType>(
                    value: TransferType.toNewRecipient,
                    icon: const Icon(
                      Icons.person_add_alt_1_rounded,
                      size: 18,
                    ),
                    label: SizedBox(
                      width: 70,
                      child: Text(
                        'Новый',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                selected: {_transferType},
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onSelectionChanged: (Set<TransferType> newSelection) {
                  setState(() {
                    _transferType = newSelection.first;
                    _toAccount = null;
                    _selectedContact = null;
                    _recipientIdController.clear();
                    _selectedRecipientBank = null;
                    // Reset debt state when switching to own accounts
                    if (_transferType == TransferType.ownAccounts) {
                      _isDebt = false;
                      _returnDate = null;
                    }
                  });
                },
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                if (_transferType == TransferType.ownAccounts) {
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return DropdownButtonFormField<BankAccount>(
                        value: _toAccount,
                        isExpanded: true,
                        isDense: true,
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textPrimary,
                        ),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        decoration: _inputDecoration(
                          hint: 'Счёт зачисления',
                          prefixIcon: Icons.account_balance_rounded,
                        ),
                        items: accounts
                            .map<DropdownMenuItem<BankAccount>>((account) {
                          final balance =
                          accountProvider.getBalance(account);
                          return DropdownMenuItem<BankAccount>(
                            value: account,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: constraints.maxWidth - 32,
                              ),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${account.displayName} • ${ApiConfig.getBankName(account.bankCode)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textPrimary,
                                      height: 1.0,
                                    ),
                                  ),
                                  Text(
                                    '${balance.toStringAsFixed(2)} ${account.currency}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textSecondary,
                                      height: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _toAccount = value),
                      );
                    },
                  );
                } else if (_transferType == TransferType.toContact) {
                  return FutureBuilder<List<Contact>>(
                    future: contactsService
                        .loadContacts()
                        .then((_) => contactsService.getAllContacts()),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return Row(
                          children: const [
                            SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Загрузка контактов...',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        );
                      }

                      final contacts = snapshot.data ?? [];

                      if (contacts.isEmpty) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Нет сохранённых контактов',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _transferType =
                                      TransferType.toNewRecipient;
                                });
                              },
                              child: const Text(
                                'Добавить новый контакт',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        );
                      }

                      return LayoutBuilder(
                        builder: (context, constraints) {
                          return DropdownButtonFormField<Contact>(
                            value: _selectedContact,
                            isExpanded: true,
                            isDense: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            decoration: _inputDecoration(
                              hint: 'Выберите контакт',
                              prefixIcon: Icons.person_rounded,
                            ),
                            items: contacts
                                .map<DropdownMenuItem<Contact>>(
                                    (contact) {
                                  return DropdownMenuItem<Contact>(
                                    value: contact,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                        constraints.maxWidth - 48,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            contact.displayName,
                                            maxLines: 2,
                                            overflow:
                                            TextOverflow.ellipsis,
                                            softWrap: true,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight:
                                              FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            contact.description,
                                            maxLines: 1,
                                            overflow:
                                            TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color:
                                              AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (value) =>
                                setState(() => _selectedContact = value),
                          );
                        },
                      );
                    },
                  );
                } else {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _recipientIdController,
                        decoration: _inputDecoration(
                          label: 'Client ID получателя',
                          prefixIcon: Icons.badge_rounded,
                          hint: 'team201-1, team201-2, и т.д.',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _recipientAccountController,
                        decoration: _inputDecoration(
                          label: 'Номер счёта получателя',
                          prefixIcon: Icons.account_box_rounded,
                          hint: '40817810...',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      if (_saveAsContact) ...[
                        TextField(
                          controller: _recipientNameController,
                          decoration: _inputDecoration(
                            label: 'Имя контакта',
                            prefixIcon: Icons.person_rounded,
                            hint: 'Например: Иван Иванов',
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return DropdownButtonFormField<String>(
                            value: _selectedRecipientBank,
                            isExpanded: true,
                            isDense: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textPrimary,
                            ),
                            dropdownColor: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            decoration: _inputDecoration(
                              label: 'Банк получателя',
                              prefixIcon: Icons.account_balance_rounded,
                            ),
                            items: banks
                                .map<DropdownMenuItem<String>>((bank) {
                              return DropdownMenuItem<String>(
                                value: bank,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                    constraints.maxWidth - 48,
                                  ),
                                  child: Text(
                                    bank.toUpperCase(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (value) => setState(
                                    () => _selectedRecipientBank = value),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '💡 Для межбанковских переводов важно указать правильный банк получателя',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                          height: 1.2,
                        ),
                      ),
                    ],
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Сумма',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              decoration: _inputDecoration(
                hint: 'Сумма в рублях',
                prefixIcon: Icons.attach_money_rounded,
                suffix: '₽',
              ),
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              // важно: без setState здесь, чтобы не дёргать всю карточку при вводе
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepChip({
    required int index,
    required String label,
    required bool active,
    required bool done,
  }) {
    Color circleColor;
    Color textColor;
    Widget inner;

    if (done) {
      circleColor = Colors.white.withValues(alpha: 0.24);
      textColor = Colors.white;
      inner = const Icon(
        Icons.check_rounded,
        size: 14,
        color: Colors.white,
      );
    } else if (active) {
      circleColor = Colors.white;
      textColor = Colors.white;
      inner = Text(
        '$index',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryBlue,
        ),
      );
    } else {
      circleColor = Colors.white.withValues(alpha: 0.16);
      textColor = Colors.white70;
      inner = Text(
        '$index',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white70,
        ),
      );
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Colors.white.withValues(alpha: active ? 0.18 : 0.12),
          border: Border.all(
            color: Colors.white.withValues(alpha: active ? 0.5 : 0.25),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circleColor,
              ),
              child: Center(child: inner),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    String? label,
    IconData? prefixIcon,
    String? hint,
    String? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        color: AppTheme.textSecondary,
      ),
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 13,
        color: AppTheme.textSecondary,
      ),
      floatingLabelBehavior:
      label == null ? FloatingLabelBehavior.never : FloatingLabelBehavior.auto,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      suffixText: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppTheme.primaryBlue.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppTheme.primaryBlue.withValues(alpha: 0.18),
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
    );
  }

  Widget _buildGlassSection({required Widget child}) {
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
            padding: const EdgeInsets.all(16),
            child: child,
          ),
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
    final amount = double.tryParse(
      _amountController.text.replaceAll(',', '.'),
    );

    if (_fromAccount == null || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.warningSnackBar('Заполните все обязательные поля'),
      );
      return;
    }

    String? recipientAccountId;
    String? recipientBank;
    String? recipientClientId;
    String? recipientName;

    if (_transferType == TransferType.ownAccounts) {
      if (_toAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.warningSnackBar('Выберите счёт получателя'),
        );
        return;
      }

      if (_fromAccount!.accountId == _toAccount!.accountId) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.warningSnackBar('Выберите разные счета'),
        );
        return;
      }

      recipientAccountId = _toAccount!.accountId;
      recipientBank = _toAccount!.bankCode;
    } else if (_transferType == TransferType.toContact) {
      if (_selectedContact == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.warningSnackBar('Выберите контакт'),
        );
        return;
      }

      if (_selectedContact!.accountId == null ||
          _selectedContact!.accountId!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.warningSnackBar('У контакта не указан номер счёта'),
        );
        return;
      }

      recipientClientId = _selectedContact!.clientId;
      recipientName = _selectedContact!.name;
      recipientBank = _selectedContact!.bankCode;
      recipientAccountId = _selectedContact!.accountId;
    } else {
      if (_recipientIdController.text.trim().isEmpty ||
          _recipientAccountController.text.trim().isEmpty ||
          _selectedRecipientBank == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.warningSnackBar('Укажите Client ID, номер счёта и банк получателя'),
        );
        return;
      }

      recipientClientId = _recipientIdController.text.trim();
      recipientAccountId = _recipientAccountController.text.trim();
      recipientBank = _selectedRecipientBank;

      if (_saveAsContact &&
          _recipientNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.warningSnackBar('Укажите имя контакта'),
        );
        return;
      }

      recipientName = _saveAsContact
          ? _recipientNameController.text.trim()
          : recipientClientId;
    }

    if (_isDebt && _returnDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        AppTheme.warningSnackBar('Укажите дату возврата долга'),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                AppTheme.iceBlue,
              ],
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
                      gradient: AppTheme.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Подтверждение перевода',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
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
                    _buildInfoRow('Сумма', '${amount.toStringAsFixed(2)} ₽', Icons.payments_rounded),
                    const Divider(height: 24),
                    _buildInfoRow('Со счёта', '${_fromAccount!.displayName} • ${ApiConfig.getBankName(_fromAccount!.bankCode)}', Icons.account_balance_wallet_rounded),
                    const Divider(height: 24),
                    _buildInfoRow('Получатель', recipientName ?? recipientClientId ?? recipientAccountId ?? '', Icons.person_rounded),
                    if (recipientBank != null) ...[
                      const Divider(height: 24),
                      _buildInfoRow('Банк', ApiConfig.getBankName(recipientBank), Icons.account_balance_rounded),
                    ],
                    if (_commentController.text.isNotEmpty) ...[
                      const Divider(height: 24),
                      _buildInfoRow('Комментарий', _commentController.text, Icons.comment_rounded),
                    ],
                  ],
                ),
              ),
              if (_isDebt) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.warningOrange.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_month_rounded,
                        color: AppTheme.warningOrange,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Долг',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.warningOrange,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Дата возврата: ${_returnDate!.day}.${_returnDate!.month}.${_returnDate!.year}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: AppTheme.gradientButtonDecoration(),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Подтвердить',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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

    if (confirmed != true) return;

    final transferProvider = context.read<TransferProvider>();

    BankAccount? targetAccount = _toAccount;

    if (_transferType != TransferType.ownAccounts) {
      if (recipientAccountId == null || recipientAccountId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.errorSnackBar('Отсутствует номер счёта получателя'),
          );
        }
        return;
      }

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
      comment: _commentController.text.trim().isNotEmpty
          ? _commentController.text.trim()
          : null,
    );

    if (success && mounted) {
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

      if (_isDebt) {
        final debtsService = DebtsService();
        await debtsService.loadDebts();
        await debtsService.addDebt(
          contactId: recipientClientId ?? recipientAccountId ?? 'unknown',
          contactName: recipientName ?? recipientClientId ?? 'Unknown',
          contactClientId: recipientClientId ?? 'unknown',
          amount: amount,
          type: DebtType.owedToMe,
          returnDate: _returnDate,
          comment: _commentController.text.trim().isNotEmpty
              ? _commentController.text.trim()
              : null,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            AppTheme.successSnackBar('Долг добавлен в список. Мы напомним о возврате!'),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          AppTheme.successSnackBar('Перевод выполнен успешно!'),
        );

        _amountController.clear();
        _commentController.clear();
        _recipientIdController.clear();
        _recipientNameController.clear();
        _recipientAccountController.clear();
        setState(() {
          _fromAccount = null;
          _toAccount = null;
          _selectedContact = null;
          _selectedRecipientBank = null;
          _isDebt = false;
          _returnDate = null;
          _saveAsContact = false;
        });

        context.read<AccountProvider>().fetchAllAccounts();
      }
    }
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryBlue),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
