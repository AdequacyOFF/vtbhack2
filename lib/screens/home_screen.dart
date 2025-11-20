import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/product_provider.dart';
import '../providers/news_provider.dart';
import '../providers/virtual_account_provider.dart';
import '../services/auth_service.dart';
import '../services/consent_polling_service.dart';
import '../services/notification_service.dart';
import '../config/app_theme.dart';
import '../config/api_config.dart';
import '../config/animations.dart';
import 'accounts_screen.dart';
import 'products_screen.dart';
import 'transfer_screen.dart';
import 'atm_map_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'news_screen.dart';
import 'virtual_accounts_screen.dart';
import 'expenses_optimization_screen.dart';

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
    final pollingService = context.read<ConsentPollingService>();
    final virtualAccountProvider = context.read<VirtualAccountProvider>();

    // Connect virtual account provider to account provider for transaction processing
    accountProvider.setVirtualAccountProvider(virtualAccountProvider);

    try {
      // Log current consent state
      debugPrint('[HomeScreen] _initialize called');
      debugPrint('[HomeScreen] hasMissingConsents: ${authService.hasMissingConsents}');

      // Auto-create missing consents ONLY if they don't exist at all
      if (authService.hasMissingConsents) {
        debugPrint('[HomeScreen] Creating missing consents...');
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
      } else {
        debugPrint('[HomeScreen] All consents exist, skipping creation');
      }

      // Refresh consent statuses to check if any were approved
      debugPrint('[HomeScreen] Refreshing consent statuses...');
      try {
        await authService.refreshAllConsents();
        debugPrint('[HomeScreen] Consent statuses refreshed successfully');
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

      // Auto-load personalized news after transactions are loaded
      _loadPersonalizedNews();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }

    setState(() => _isInitialized = true);
  }

  /// Automatically loads personalized news based on transaction history
  void _loadPersonalizedNews() {
    // Use addPostFrameCallback to avoid calling provider methods during build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final newsProvider = context.read<NewsProvider>();
      final accountProvider = context.read<AccountProvider>();

      final allTransactions = accountProvider.allTransactions;

      if (allTransactions.isNotEmpty) {
        debugPrint('[HomeScreen] Auto-loading personalized news with ${allTransactions.length} transactions');
        try {
          await newsProvider.fetchPersonalizedNews(
            transactions: allTransactions,
            n: 10,
            maxCategories: 5,
          );
          debugPrint('[HomeScreen] Personalized news loaded successfully');
        } catch (e) {
          debugPrint('[HomeScreen] Error auto-loading news: $e');
          // Don't show error to user, news is optional
        }
      } else {
        debugPrint('[HomeScreen] No transactions available for personalized news');
      }
    });
  }

  // iOS App Store Style Bottom Navigation Bar with Glass Effect
  Widget _buildIOSAppStoreBottomBar() {
    return Container(
      margin: const EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 20,
      ),
      height: 76,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34), // Pill shape
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(34),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue.withValues(alpha: 0.12), // Blue tint top
                  AppTheme.primaryBlue.withValues(alpha: 0.08), // Lighter bottom
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(
                color: AppTheme.primaryBlue.withValues(alpha: 0.25), // Blue border
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(
                  icon: Icons.home_rounded,
                  label: 'Главная',
                  index: 0,
                ),
                _buildNavItem(
                  icon: Icons.location_on_rounded,
                  label: 'Банкоматы',
                  index: 1,
                ),
                _buildNavItem(
                  icon: Icons.article_rounded,
                  label: 'Новости',
                  index: 2,
                ),
                _buildNavItem(
                  icon: Icons.person_rounded,
                  label: 'Профиль',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with background highlight
              Container(
                width: 36,
                height: 36,
                decoration: isSelected
                    ? BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      )
                    : null,
                child: Icon(
                  icon,
                  size: 24,
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : AppTheme.textPrimary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 4),
              // Label
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppTheme.primaryBlue
                      : AppTheme.textPrimary.withValues(alpha: 0.7),
                  letterSpacing: 0.1,
                  height: 1.1, // Tighter line height to prevent overflow
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern iOS 26 style notification bell icon with badge
  Widget _buildNotificationIcon(BuildContext context) {
    final unreadCount = context.watch<NotificationService>().unreadCount;

    return Stack(
      children: [
        const Icon(Icons.notifications_rounded, size: 28),
        if (unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.errorRed,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.errorRed.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
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
      const AtmMapScreen(),
      const NewsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      extendBody: true, // Allow body to extend behind bottom bar
      backgroundColor: AppTheme.backgroundLight,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AppBar(
              title: const Text(
                'Multi-Bank App',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              backgroundColor: AppTheme.darkBlue.withValues(alpha: 0.9),
              elevation: 0,
              actions: [
                // Notification bell icon in top-right with badge
                IconButton(
                  icon: _buildNotificationIcon(context),
                  onPressed: () {
                    Navigator.of(context).push(
                      AppAnimations.createRoute(const NotificationsScreen()),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, size: 24),
                  onPressed: _initialize,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
      body: _isInitialized
          ? AnimatedSwitcher(
              duration: AppAnimations.normal,
              switchInCurve: AppAnimations.smooth,
              switchOutCurve: AppAnimations.smooth,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.02, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Container(
                key: ValueKey<int>(_selectedIndex),
                child: screens[_selectedIndex],
              ),
            )
          : const Center(child: CircularProgressIndicator()),
      bottomNavigationBar: _buildIOSAppStoreBottomBar(),
    );
  }
}

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  // iOS 26 Quick Action Button
  Widget _buildQuickActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 125,
      decoration: AppTheme.quickActionDecoration(color: color),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _retryConsent(BuildContext context, String bankCode) async {
    final authService = context.read<AuthService>();
    final accountProvider = context.read<AccountProvider>();

    // First check if consent already exists and is approved
    if (authService.hasRequiredConsents(bankCode)) {
      debugPrint('[DashboardTab] Consent for $bankCode is already approved, refreshing instead of recreating');

      // Just refresh the status and reload accounts instead of recreating
      try {
        await authService.refreshAccountConsentStatus(bankCode);
        await accountProvider.fetchAllAccounts();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Данные ${ApiConfig.getBankName(bankCode)} обновлены'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка обновления: $e'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
      }
      return;
    }

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
      debugPrint('[DashboardTab] Recreating consent for $bankCode');
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
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 110, // Space for floating bottom bar (68 height + 20 margin + 22 extra)
            ),
            children: [
              // Pending Consent Banner - iOS 26 Glass Style
              if (pendingBanks.isNotEmpty) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: AppTheme.glassDecoration(
                    color: AppTheme.primaryBlue,
                    opacity: 0.08,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
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
                  ),
                ),
              ],

              // Consent Notifications - iOS 26 Glass Style
              if (consentErrors.isNotEmpty) ...[
                ...consentErrors.entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: AppTheme.glassDecoration(
                      color: AppTheme.warningOrange,
                      opacity: 0.08,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
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
                      ),
                    ),
                  );
                }).toList(),
                const SizedBox(height: 8),
              ],

              // Total Balance Card - Modern iOS 26 Style with Gradient
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: AppTheme.modernCardDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: 24,
                ),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white.withValues(alpha: 0.9),
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Общий баланс',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '${totalBalance.toStringAsFixed(2)} ₽',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${accountProvider.accounts.length} счетов из ${accountsByBank.length} банков',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Quick Actions - iOS 26 Style
              Row(
                children: [
                  Expanded(
                    child: _buildQuickActionButton(
                      context: context,
                      icon: Icons.account_balance_rounded,
                      label: 'Продукты',
                      color: AppTheme.primaryBlue,
                      onTap: () {
                        Navigator.of(context).push(
                          AppAnimations.createRoute(const ProductsScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildQuickActionButton(
                      context: context,
                      icon: Icons.swap_horizontal_circle_rounded,
                      label: 'Переводы',
                      color: AppTheme.accentBlue,
                      onTap: () {
                        Navigator.of(context).push(
                          AppAnimations.createRoute(const TransferScreen()),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Virtual Accounts - Full Width Button
              _buildQuickActionButton(
                context: context,
                icon: Icons.account_balance_wallet_outlined,
                label: 'Виртуальные счета',
                color: const Color(0xFF6366F1), // Indigo color
                onTap: () {
                  Navigator.of(context).push(
                    AppAnimations.createRoute(const VirtualAccountsScreen()),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Expenses Optimization - Full Width Button
              _buildQuickActionButton(
                context: context,
                icon: Icons.auto_awesome,
                label: 'Оптимизация расходов',
                color: const Color(0xFF10B981), // Emerald green color
                onTap: () {
                  Navigator.of(context).push(
                    AppAnimations.createRoute(const ExpensesOptimizationScreen()),
                  );
                },
              ),

              const SizedBox(height: 28),

              // Accounts by Bank
              ...accountsByBank.entries.map((entry) {
                final bankCode = entry.key;
                final accounts = entry.value;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // iOS 26 Style Section Header
                    Container(
                      margin: const EdgeInsets.only(bottom: 12, top: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.iceBlue,
                            AppTheme.iceBlue.withValues(alpha: 0.3),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.account_balance_rounded,
                              size: 18,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            ApiConfig.getBankName(bankCode),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkBlue,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${accounts.length}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...accounts.asMap().entries.map((entry) {
                      final index = entry.key;
                      final account = entry.value;
                      final balance = accountProvider.getBalance(account);

                      return AppAnimations.slideIn(
                        index: index,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: AppTheme.modernCardDecoration(borderRadius: 20),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () {
                                Navigator.of(context).push(
                                  AppAnimations.createRoute(
                                    AccountsScreen(account: account),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.accentGradient,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            account.displayName,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: AppTheme.textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            account.accountSubType,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${balance.toStringAsFixed(2)} ${account.currency}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                            color: AppTheme.darkBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Icon(
                                          Icons.arrow_forward_ios_rounded,
                                          size: 14,
                                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
