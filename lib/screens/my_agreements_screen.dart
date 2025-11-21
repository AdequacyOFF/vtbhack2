import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../config/app_theme.dart';
import '../config/api_config.dart';

class MyAgreementsScreen extends StatefulWidget {
  const MyAgreementsScreen({super.key});

  @override
  State<MyAgreementsScreen> createState() => _MyAgreementsScreenState();
}

class _MyAgreementsScreenState extends State<MyAgreementsScreen> {
  Map<String, List<Map<String, dynamic>>> _agreementsByBank = {};
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAgreements();
  }

  Future<void> _loadAgreements() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = context.read<AuthService>();
      final clientId = authService.clientId;
      final agreements = <String, List<Map<String, dynamic>>>{};

      debugPrint('[MyAgreements] Starting to load product agreements for client: $clientId');

      for (final bankCode in ['vbank', 'abank', 'sbank', 'babank']) {
        try {
          final service = authService.getBankService(bankCode);

          // Get product consent (will create if missing)
          final consent = await authService.getProductConsent(bankCode);
          debugPrint('[$bankCode] Product consent status: ${consent.status}');

          if (consent.isApproved) {
            final bankAgreements = await service.getProductAgreements(
              clientId: clientId,
              consentId: consent.consentId,
            );
            agreements[bankCode] = bankAgreements;
            debugPrint('[$bankCode] Loaded ${bankAgreements.length} product agreements');

            // Debug: print first agreement details if available
            if (bankAgreements.isNotEmpty) {
              debugPrint('[$bankCode] Sample agreement: ${bankAgreements.first}');
            }
          } else {
            debugPrint('[$bankCode] Product consent not approved: ${consent.status}');
            agreements[bankCode] = [];
          }
        } catch (e) {
          debugPrint('[$bankCode] Error loading agreements: $e');
          agreements[bankCode] = [];
        }
      }

      final totalAgreements = agreements.values.fold(0, (sum, list) => sum + list.length);
      debugPrint('[MyAgreements] Total agreements loaded: $totalAgreements');

      setState(() {
        _agreementsByBank = agreements;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[MyAgreements] Fatal error: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get allDeposits {
    final deposits = <Map<String, dynamic>>[];
    _agreementsByBank.forEach((bankCode, agreements) {
      for (final agreement in agreements) {
        if (agreement['product_type'] == 'deposit' ||
            agreement['productType'] == 'deposit') {
          deposits.add({...agreement, 'bank_code': bankCode});
        }
      }
    });
    return deposits;
  }

  List<Map<String, dynamic>> get allLoans {
    final loans = <Map<String, dynamic>>[];
    _agreementsByBank.forEach((bankCode, agreements) {
      for (final agreement in agreements) {
        if (agreement['product_type'] == 'loan' ||
            agreement['productType'] == 'loan') {
          loans.add({...agreement, 'bank_code': bankCode});
        }
      }
    });
    return loans;
  }

  List<Map<String, dynamic>> get allCards {
    final cards = <Map<String, dynamic>>[];
    _agreementsByBank.forEach((bankCode, agreements) {
      for (final agreement in agreements) {
        if (agreement['product_type'] == 'card' ||
            agreement['productType'] == 'card') {
          cards.add({...agreement, 'bank_code': bankCode});
        }
      }
    });
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Мои продукты',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: AppTheme.primaryBlue,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'Депозиты'),
              Tab(text: 'Кредиты'),
              Tab(text: 'Карты'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAgreements,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Ошибка: $_error'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAgreements,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    children: [
                      _DepositsTab(
                        deposits: allDeposits,
                        onRefresh: _loadAgreements,
                      ),
                      _LoansTab(
                        loans: allLoans,
                        onRefresh: _loadAgreements,
                      ),
                      _CardsTab(
                        cards: allCards,
                        onRefresh: _loadAgreements,
                      ),
                    ],
                  ),
      ),
    );
  }
}

// Deposits Tab
class _DepositsTab extends StatelessWidget {
  final List<Map<String, dynamic>> deposits;
  final VoidCallback onRefresh;

  const _DepositsTab({required this.deposits, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (deposits.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет активных депозитов'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: deposits.length,
      itemBuilder: (context, index) {
        final deposit = deposits[index];
        final bankCode = deposit['bank_code'] as String;
        final agreementId = deposit['agreement_id'] ?? deposit['agreementId'];
        final amount = deposit['amount'] ?? 0.0;
        final interestRate = deposit['interest_rate'] ?? deposit['interestRate'] ?? 0.0;
        final status = deposit['status'] ?? 'active';
        final productName = deposit['product_name'] ?? deposit['productName'] ?? 'Депозит';
        final createdAt = deposit['created_at'] ?? deposit['createdAt'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.successGreen.withOpacity(0.1),
                      child: const Icon(Icons.savings, color: AppTheme.successGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            ApiConfig.getBankName(bankCode),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'active'
                            ? AppTheme.successGreen.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status == 'active' ? 'Активен' : status,
                        style: TextStyle(
                          color: status == 'active' ? AppTheme.successGreen : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Сумма', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '${amount.toStringAsFixed(2)} ₽',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Ставка', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '$interestRate%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Открыт: $createdAt',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 12),
                if (status == 'active')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _closeDeposit(context, bankCode, agreementId, onRefresh),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Закрыть досрочно'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.errorRed,
                        side: const BorderSide(color: AppTheme.errorRed),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _closeDeposit(
    BuildContext context,
    String bankCode,
    String agreementId,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Закрыть депозит?'),
        content: const Text(
          'Вы уверены, что хотите закрыть депозит досрочно? '
          'Это может привести к потере процентов.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authService = context.read<AuthService>();
      final service = authService.getBankService(bankCode);
      final consent = await authService.getProductConsent(bankCode);

      await service.closeProductAgreement(
        agreementId: agreementId,
        clientId: authService.clientId,
        consentId: consent.consentId,
        earlyTermination: true,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Депозит успешно закрыт')),
        );
        onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}

// Loans Tab
class _LoansTab extends StatelessWidget {
  final List<Map<String, dynamic>> loans;
  final VoidCallback onRefresh;

  const _LoansTab({required this.loans, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (loans.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет активных кредитов'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: loans.length,
      itemBuilder: (context, index) {
        final loan = loans[index];
        final bankCode = loan['bank_code'] as String;
        final agreementId = loan['agreement_id'] ?? loan['agreementId'];
        final amount = loan['amount'] ?? 0.0;
        final interestRate = loan['interest_rate'] ?? loan['interestRate'] ?? 0.0;
        final status = loan['status'] ?? 'active';
        final productName = loan['product_name'] ?? loan['productName'] ?? 'Кредит';
        final createdAt = loan['created_at'] ?? loan['createdAt'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.warningOrange.withOpacity(0.1),
                      child: const Icon(Icons.account_balance_wallet, color: AppTheme.warningOrange),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            ApiConfig.getBankName(bankCode),
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'active'
                            ? AppTheme.warningOrange.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status == 'active' ? 'Активен' : status,
                        style: TextStyle(
                          color: status == 'active' ? AppTheme.warningOrange : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Сумма', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '${amount.toStringAsFixed(2)} ₽',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Ставка', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          '$interestRate%',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.warningOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (createdAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Открыт: $createdAt',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 12),
                if (status == 'active')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _closeLoan(context, bankCode, agreementId, onRefresh),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Погасить досрочно'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.warningOrange,
                        side: const BorderSide(color: AppTheme.warningOrange),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _closeLoan(
    BuildContext context,
    String bankCode,
    String agreementId,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Погасить кредит?'),
        content: const Text(
          'Вы уверены, что хотите погасить кредит досрочно? '
          'Убедитесь, что на счету достаточно средств.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Погасить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authService = context.read<AuthService>();
      final service = authService.getBankService(bankCode);
      final consent = await authService.getProductConsent(bankCode);

      await service.closeProductAgreement(
        agreementId: agreementId,
        clientId: authService.clientId,
        consentId: consent.consentId,
        earlyTermination: true,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Кредит успешно погашен')),
        );
        onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}

// Cards Tab
class _CardsTab extends StatelessWidget {
  final List<Map<String, dynamic>> cards;
  final VoidCallback onRefresh;

  const _CardsTab({required this.cards, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Нет активных карт'),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final card = cards[index];
        final bankCode = card['bank_code'] as String;
        final agreementId = card['agreement_id'] ?? card['agreementId'];
        final amount = card['amount'] ?? card['limit'] ?? 0.0;
        final status = card['status'] ?? 'active';
        final productName = card['product_name'] ?? card['productName'] ?? 'Карта';
        final cardNumber = card['card_number'] ?? card['cardNumber'];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.accentBlue.withOpacity(0.1),
                      child: const Icon(Icons.credit_card, color: AppTheme.accentBlue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            productName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            ApiConfig.getBankName(bankCode),
                            style: const TextStyle(color: Colors.grey),
                          ),
                          if (cardNumber != null)
                            Text(
                              '**** **** **** ${cardNumber.toString().substring(cardNumber.toString().length - 4)}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: status == 'active'
                            ? AppTheme.accentBlue.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status == 'active' ? 'Активна' : status,
                        style: TextStyle(
                          color: status == 'active' ? AppTheme.accentBlue : Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    const Text('Лимит: ', style: TextStyle(color: Colors.grey)),
                    Text(
                      '${amount.toStringAsFixed(2)} ₽',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: status == 'active'
                            ? () => _blockCard(context, bankCode, agreementId, onRefresh)
                            : () => _unblockCard(context, bankCode, agreementId, onRefresh),
                        icon: Icon(
                          status == 'active' ? Icons.block : Icons.check_circle,
                          size: 18,
                        ),
                        label: Text(status == 'active' ? 'Заблокировать' : 'Разблокировать'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: status == 'active' ? AppTheme.errorRed : AppTheme.successGreen,
                          side: BorderSide(
                            color: status == 'active' ? AppTheme.errorRed : AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _blockCard(
    BuildContext context,
    String bankCode,
    String cardId,
    VoidCallback onRefresh,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Заблокировать карту?'),
        content: const Text('Вы уверены, что хотите заблокировать эту карту?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Заблокировать'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authService = context.read<AuthService>();
      final service = authService.getBankService(bankCode);
      final consent = await authService.getProductConsent(bankCode);

      await service.updateCardStatus(
        cardId: cardId,
        clientId: authService.clientId,
        consentId: consent.consentId,
        status: 'blocked',
        reason: 'User requested block',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Карта заблокирована')),
        );
        onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _unblockCard(
    BuildContext context,
    String bankCode,
    String cardId,
    VoidCallback onRefresh,
  ) async {
    try {
      final authService = context.read<AuthService>();
      final service = authService.getBankService(bankCode);
      final consent = await authService.getProductConsent(bankCode);

      await service.updateCardStatus(
        cardId: cardId,
        clientId: authService.clientId,
        consentId: consent.consentId,
        status: 'active',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Карта разблокирована')),
        );
        onRefresh();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }
}
