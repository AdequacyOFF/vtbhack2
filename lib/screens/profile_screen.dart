import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/account_provider.dart';
import '../services/pdf_service.dart';
import '../services/analytics_service.dart';
import '../config/app_theme.dart';
import 'login_screen.dart';
import 'consent_management_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 16),

          // Profile Header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.primaryBlue,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authService.clientId,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  const Text('Пользователь Multi-Bank App'),
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
            icon: Icons.analytics,
            title: 'Экспорт для ML анализа',
            subtitle: 'Получить данные для нейросети',
            onTap: () => _exportForML(context),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
          child: Icon(icon, color: AppTheme.primaryBlue),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
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
            title: const Text('PDF создан'),
            content: Text('Файл сохранен: ${file.path}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ОК'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  PdfService.sharePdf(file);
                },
                child: const Text('Поделиться'),
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
