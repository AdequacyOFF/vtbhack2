import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/consent_polling_service.dart';
import '../config/api_config.dart';
import '../config/app_theme.dart';

class ConsentManagementScreen extends StatefulWidget {
  const ConsentManagementScreen({super.key});

  @override
  State<ConsentManagementScreen> createState() => _ConsentManagementScreenState();
}

class _ConsentManagementScreenState extends State<ConsentManagementScreen> {
  bool _isCreatingConsents = false;
  bool _isRefreshing = false;
  Map<String, bool>? _lastResults;
  Map<String, bool>? _lastRefreshResults;

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final pollingService = context.read<ConsentPollingService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Управление согласиями'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.primaryBlue),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Управление согласиями на доступ к данным',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Согласия необходимы для доступа к счетам, балансам и транзакциям в банках-партнерах. '
                    'Некоторые банки требуют ручного подтверждения в личном кабинете.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Polling Status Indicator
          if (pollingService.isPolling) ...[
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Автоматическая проверка статусов',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Проверка ${pollingService.pollCount} из ${ConsentPollingService.maxPollAttempts}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        pollingService.stopPolling();
                        setState(() {});
                      },
                      child: const Text('Остановить'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Create All Consents Button
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isCreatingConsents ? null : _createAllConsents,
                    icon: _isCreatingConsents
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add_task),
                    label: const Text('Создать согласия для всех банков'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _isRefreshing ? null : _refreshAllConsents,
                    icon: _isRefreshing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.sync),
                    label: const Text('Проверить статусы всех согласий'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                  if (_lastResults != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Результаты создания согласий:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._lastResults!.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              entry.value ? Icons.check_circle : Icons.error,
                              color: entry.value ? AppTheme.successGreen : AppTheme.errorRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ApiConfig.getBankName(entry.key),
                              style: TextStyle(
                                color: entry.value ? AppTheme.successGreen : AppTheme.errorRed,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                  if (_lastRefreshResults != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    const Text(
                      'Результаты проверки статусов:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._lastRefreshResults!.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              entry.value ? Icons.check_circle : Icons.error,
                              color: entry.value ? AppTheme.successGreen : AppTheme.errorRed,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              ApiConfig.getBankName(entry.key),
                              style: TextStyle(
                                color: entry.value ? AppTheme.successGreen : AppTheme.errorRed,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Individual Bank Consents
          Text(
            'Согласия по банкам',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),

          ...authService.supportedBanks.map((bankCode) {
            final consentStatus = authService.getConsentStatus(bankCode);
            final hasConsent = authService.hasRequiredConsents(bankCode);

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                leading: Icon(
                  hasConsent ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: hasConsent ? AppTheme.successGreen : AppTheme.warningOrange,
                ),
                title: Text(ApiConfig.getBankName(bankCode)),
                subtitle: Text(
                  hasConsent ? 'Согласие активно' : 'Требуется создание согласия',
                  style: TextStyle(
                    color: hasConsent ? AppTheme.successGreen : AppTheme.warningOrange,
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildConsentInfo('Согласие на счета', consentStatus['account_consent']),
                        const Divider(),
                        _buildConsentInfo('Согласие на платежи', consentStatus['payment_consent']),
                        const Divider(),
                        _buildConsentInfo('Согласие на продукты', consentStatus['product_consent']),
                        const SizedBox(height: 16),
                        if (ApiConfig.requiresManualApproval(bankCode))
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.warningOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info, color: AppTheme.warningOrange, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Требуется ручное подтверждение в личном кабинете ${ApiConfig.getBankName(bankCode)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _checkConsentStatus(bankCode),
                                icon: const Icon(Icons.sync, size: 18),
                                label: const Text('Проверить статус'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _recreateConsent(bankCode),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: const Text('Пересоздать'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildConsentInfo(String title, dynamic consentData) {
    if (consentData == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title),
            const Text(
              'Не создано',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final status = consentData['status'] ?? 'unknown';
    final consentId = consentData['consentId'] ?? 'N/A';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == 'approved'
                      ? AppTheme.successGreen.withValues(alpha: 0.1)
                      : AppTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  status == 'approved' ? 'Одобрено' : status,
                  style: TextStyle(
                    fontSize: 12,
                    color: status == 'approved' ? AppTheme.successGreen : AppTheme.warningOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'ID: $consentId',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Future<void> _createAllConsents() async {
    setState(() => _isCreatingConsents = true);

    try {
      final authService = context.read<AuthService>();
      final pollingService = context.read<ConsentPollingService>();
      final results = await authService.createAllConsents();

      setState(() {
        _lastResults = results;
        _isCreatingConsents = false;
      });

      if (mounted) {
        final successCount = results.values.where((v) => v).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Создано согласий: $successCount из ${results.length}'),
            backgroundColor: successCount > 0 ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        );

        // Start polling if there are pending consents
        if (authService.hasPendingConsents && !pollingService.isPolling) {
          pollingService.startPolling();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Запущена автоматическая проверка статусов'),
              backgroundColor: AppTheme.primaryBlue,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isCreatingConsents = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _recreateConsent(String bankCode) async {
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
      final authService = context.read<AuthService>();
      final pollingService = context.read<ConsentPollingService>();
      await authService.recreateAccountConsent(bankCode);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        setState(() {}); // Refresh UI

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Согласие для ${ApiConfig.getBankName(bankCode)} успешно создано'),
            backgroundColor: AppTheme.successGreen,
          ),
        );

        // Start polling if consent is pending
        if (authService.hasPendingConsents && !pollingService.isPolling) {
          pollingService.startPolling();
        }
      }
    } catch (e) {
      if (mounted) {
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

  Future<void> _refreshAllConsents() async {
    setState(() => _isRefreshing = true);

    try {
      final authService = context.read<AuthService>();
      final results = await authService.refreshAllConsents();

      setState(() {
        _lastRefreshResults = results;
        _isRefreshing = false;
      });

      if (mounted) {
        final successCount = results.values.where((v) => v).length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Обновлено статусов: $successCount из ${results.length}'),
            backgroundColor: successCount > 0 ? AppTheme.successGreen : AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      setState(() => _isRefreshing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _checkConsentStatus(String bankCode) async {
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
                Text('Проверка статуса...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final authService = context.read<AuthService>();
      await authService.refreshAllConsentsForBank(bankCode);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        setState(() {}); // Refresh UI

        final hasConsent = authService.hasRequiredConsents(bankCode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              hasConsent
                  ? 'Согласие для ${ApiConfig.getBankName(bankCode)} активно!'
                  : 'Согласие для ${ApiConfig.getBankName(bankCode)} ожидает подтверждения',
            ),
            backgroundColor: hasConsent ? AppTheme.successGreen : AppTheme.warningOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка проверки статуса: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }
}
