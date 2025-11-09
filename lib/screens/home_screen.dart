import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/product_provider.dart';
import '../services/auth_service.dart';
import '../services/consent_polling_service.dart';
import '../services/notification_service.dart'; // Добавьте этот импорт
import '../config/app_theme.dart';
import '../config/api_config.dart';
import 'accounts_screen.dart';
import 'products_screen.dart';
import 'transfer_screen.dart';
import 'atm_map_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart'; // Добавьте этот импорт
import 'news_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupPollingCallbacks();
    _initialize();
  }

  void _setupPollingCallbacks() {
    final pollingService = context.read<ConsentPollingService>();
    final accountProvider = context.read<AccountProvider>();

    // Setup callback for when a consent is approved
    pollingService.onConsentApproved((bankCode) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Согласие одобрено: ${ApiConfig.getBankName(bankCode)}'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 3),
          ),
        );

        // Refresh accounts to fetch data from newly approved bank
        accountProvider.fetchAllAccounts();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app resumes from background, refresh consent statuses
    if (state == AppLifecycleState.resumed && _isInitialized) {
      _refreshConsentStatuses();
    }
  }

  Future<void> _refreshConsentStatuses() async {
    final authService = context.read<AuthService>();
    final accountProvider = context.read<AccountProvider>();

    try {
      // Store old pending consents
      final oldPendingBanks = Set<String>.from(authService.banksWithPendingConsents);

      // Refresh all consent statuses
      await authService.refreshAllConsents();

      // Check which consents were newly approved
      final newlyApprovedBanks = <String>[];
      for (final bankCode in oldPendingBanks) {
        if (authService.hasRequiredConsents(bankCode)) {
          newlyApprovedBanks.add(bankCode);
        }
      }

      // Show notification if any consents were approved
      if (mounted && newlyApprovedBanks.isNotEmpty) {
        final bankNames = newlyApprovedBanks
            .map((code) => ApiConfig.getBankName(code))
            .join(', ');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Согласия одобрены: $bankNames'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Re-fetch accounts in case new consents were approved
      if (newlyApprovedBanks.isNotEmpty) {
        await accountProvider.fetchAllAccounts();
      }
    } catch (e) {
      debugPrint('Failed to refresh consent statuses: $e');
    }
  }

  Future<void> _initialize() async {
    final authService = context.read<AuthService>();
    final accountProvider = context.read<AccountProvider>();
    final productProvider = context.read<ProductProvider>();
    final notificationService = context.read<NotificationService>();
    final pollingService = context.read<ConsentPollingService>();

    try {
      // Auto-create missing consents on first load
      if (authService.hasMissingConsents) {
        final consentResults = await authService.autoCreateMissingConsents();

        final successCount = consentResults.values.where((v) => v).length;
        final totalCount = consentResults.length;

        if (mounted && successCount > 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Автоматически созданы согласия: $successCount из $totalCount'),
              backgroundColor: successCount == totalCount ? AppTheme.successGreen : AppTheme.warningOrange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }

      // Refresh consent statuses to check if any were approved
      try {
        await authService.refreshAllConsents();
      } catch (e) {
        // Continue even if refresh fails
        debugPrint('Failed to refresh consents: $e');
      }

      // Start polling if there are pending consents
      if (authService.hasPendingConsents && !pollingService.isPolling) {
        debugPrint('[HomeScreen] Starting consent polling for pending banks: ${authService.banksWithPendingConsents}');
        pollingService.startPolling();
      }

      // Fetch accounts and products
      await Future.wait([
        accountProvider.fetchAllAccounts(),
        productProvider.fetchAllProducts(),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }

    setState(() => _isInitialized = true);
  }

  // ДОБАВЬТЕ ЭТОТ МЕТОД - он должен быть внутри класса _HomeScreenState
  Widget _buildNotificationIcon(BuildContext context) {
    final unreadCount = context.watch<NotificationService>().unreadCount;

    return Stack(
      children: [
        const Icon(Icons.notifications),
        if (unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      const DashboardTab(),
      const ProductsScreen(),
      const TransferScreen(),
      const AtmMapScreen(),
      const NewsScreen(), // News screen
      const NotificationsScreen(), // Новая страница уведомлений
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multi-Bank App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initialize,
          ),
        ],
      ),
      body: _isInitialized
          ? screens[_selectedIndex]
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryBlue,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Главная',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: 'Продукты',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.swap_horiz),
            label: 'Переводы',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Банкоматы',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: 'Новости',
          ),
          BottomNavigationBarItem(
            icon: _buildNotificationIcon(context), // Иконка с бейджем
            label: 'Уведомления',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  Future<void> _retryConsent(BuildContext context, String bankCode) async {
    final authService = context.read<AuthService>();
    final accountProvider = context.read<AccountProvider>();

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Создание согласия...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Recreate account consent
      await authService.recreateAccountConsent(bankCode);

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Согласие для ${ApiConfig.getBankName(bankCode)} успешно создано'),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        // Reload accounts
        await accountProvider.fetchAllAccounts();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AccountProvider, AuthService>(
      builder: (context, accountProvider, authService, child) {
        if (accountProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (accountProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(accountProvider.error!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: accountProvider.fetchAllAccounts,
                  child: const Text('Повторить'),
                ),
              ],
            ),
          );
        }

        final accountsByBank = accountProvider.accountsByBank;
        final totalBalance = accountProvider.totalBalance;
        final consentErrors = accountProvider.consentErrors;
        final pendingBanks = authService.banksWithPendingConsents;

        return RefreshIndicator(
          onRefresh: accountProvider.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Pending Consent Banner
              if (pendingBanks.isNotEmpty) ...[
                Card(
                  color: Colors.blue.shade50,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.pending_actions,
                              color: AppTheme.primaryBlue,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ожидание одобрения согласий',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Банки: ${pendingBanks.map((code) => ApiConfig.getBankName(code)).join(', ')}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Пожалуйста, перейдите в личный кабинет банка и подтвердите согласие на доступ к данным. После подтверждения вернитесь в приложение.',
                          style: TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final pollingService = context.read<ConsentPollingService>();

                              // Show loading indicator
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Проверка статусов согласий...'),
                                  duration: Duration(seconds: 1),
                                ),
                              );

                              // Trigger immediate poll
                              await pollingService.pollNow();

                              if (context.mounted) {
                                await accountProvider.fetchAllAccounts();

                                // Check if consents are still pending
                                if (authService.banksWithPendingConsents.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('✓ Все согласия одобрены!'),
                                      backgroundColor: AppTheme.successGreen,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Ожидание одобрения: ${authService.banksWithPendingConsents.map((c) => ApiConfig.getBankName(c)).join(", ")}',
                                      ),
                                      backgroundColor: AppTheme.warningOrange,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.sync, size: 18),
                            label: const Text('Проверить статус'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Consent Notifications
              if (consentErrors.isNotEmpty) ...[
                ...consentErrors.entries.map((entry) {
                  return Card(
                    color: AppTheme.warningOrange.withValues(alpha: 0.1),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.warningOrange,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ApiConfig.getBankName(entry.key),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      entry.value,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (ApiConfig.requiresManualApproval(entry.key)) ...[
                            const SizedBox(height: 8),
                            const Text(
                              'Этот банк требует ручного подтверждения согласия в личном кабинете банка',
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _retryConsent(context, entry.key),
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Повторить создание согласия'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                backgroundColor: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
              ],

              // Total Balance Card
              Card(
                elevation: 4,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryBlue, AppTheme.lightBlue],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Общий баланс',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${totalBalance.toStringAsFixed(2)} ₽',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${accountProvider.accounts.length} счетов',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Accounts by Bank
              ...accountsByBank.entries.map((entry) {
                final bankCode = entry.key;
                final accounts = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            ApiConfig.getBankName(bankCode),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    ...accounts.map((account) {
                      final balance = accountProvider.getBalance(account);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            child: const Icon(Icons.account_balance_wallet, color: AppTheme.primaryBlue),
                          ),
                          title: Text(account.displayName),
                          subtitle: Text(account.accountSubType),
                          trailing: Text(
                            '${balance.toStringAsFixed(2)} ${account.currency}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AccountsScreen(account: account),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                  ],
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
