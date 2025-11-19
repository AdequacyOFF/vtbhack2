import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/account_provider.dart';
import '../services/pdf_service.dart';
import '../services/analytics_service.dart';
import '../config/app_theme.dart';
import 'login_screen.dart';
import 'consent_management_screen.dart';
import 'pdf_viewer_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 110, // Space for floating bottom bar
        ),
        children: [
          const SizedBox(height: 16),

          // Profile Header - iOS 26 Glass Style
          Container(
            decoration: AppTheme.modernCardDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: 24,
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.3),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 3,
                      ),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    authService.clientId,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Пользователь Multi-Bank App',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Actions
          _buildActionCard(
            context,
            icon: Icons.admin_panel_settings,
            title: 'Управление согласиями',
            subtitle: 'Просмотр и создание согласий для банков',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConsentManagementScreen()),
              );
            },
          ),

          _buildActionCard(
            context,
            icon: Icons.picture_as_pdf,
            title: 'Выгрузить выписку в PDF',
            subtitle: 'Создать PDF со всеми счетами и транзакциями',
            onTap: () => _generatePdf(context),
          ),

          _buildActionCard(
            context,
            icon: Icons.link,
            title: 'Связать соцсети',
            subtitle: 'Переводы по никнейму',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Функция в разработке')),
              );
            },
          ),

          _buildActionCard(
            context,
            icon: Icons.add_card,
            title: 'Открыть счет в партнерском банке',
            subtitle: 'Используя данные текущих счетов',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Функция в разработке')),
              );
            },
          ),

          const SizedBox(height: 16),

          // Logout Button
          ElevatedButton(
            onPressed: () => _logout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.modernCardDecoration(borderRadius: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context) async {
    final accountProvider = context.read<AccountProvider>();

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Генерация PDF...')),
      );

      final file = await PdfService.generateAccountStatement(
        accounts: accountProvider.accounts,
        transactionsByAccount: accountProvider.transactions,
        balances: accountProvider.balances,
      );

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('PDF создан'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выберите действие:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Файл: ${file.path.split('/').last}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  PdfService.sharePdf(file);
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Поделиться'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(
                        filePath: file.path,
                        title: 'Выписка по счетам',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Открыть'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  void _exportForML(BuildContext context) {
    final accountProvider = context.read<AccountProvider>();
    final allTransactions = accountProvider.allTransactions;

    final mlData = AnalyticsService.exportForML(allTransactions);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Данные для ML'),
        content: SingleChildScrollView(
          child: Text(mlData.toString()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthService>().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}
