import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../config/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          Consumer<NotificationService>(
            builder: (context, notificationService, _) {
              final autoDeleteCount = notificationService.autoDeleteableCount;
              if (autoDeleteCount > 0) {
                return IconButton(
                  icon: Badge(
                    label: Text(autoDeleteCount.toString()),
                    child: const Icon(Icons.auto_delete),
                  ),
                  onPressed: () => _autoDeleteRead(notificationService),
                  tooltip: 'Удалить прочитанные ($autoDeleteCount)',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearAllNotifications,
            tooltip: 'Очистить все',
          ),
        ],
      ),
      body: Consumer<NotificationService>(
        builder: (context, notificationService, child) {
          final notifications = notificationService.notifications;

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Нет уведомлений',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 110, // Space for floating bottom bar
            ),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return Dismissible(
                key: Key(notification.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (direction) {
                  notificationService.removeNotification(notification.id);
                },
                child: Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: _getNotificationColor(notification.type),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        _getNotificationIcon(notification.type),
                        if (notification.isImportant)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.star,
                                color: Colors.white,
                                size: 8,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (!notification.isImportant && !notification.isUnread)
                          const Tooltip(
                            message: 'Будет удалено автоматически',
                            child: Icon(Icons.auto_delete, size: 16, color: Colors.grey),
                          ),
                      ],
                    ),
                    subtitle: Text(notification.message),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _formatTime(notification.timestamp),
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (notification.isUnread)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    onTap: () {
                      notificationService.markAsRead(notification.id);
                      // Здесь можно добавить навигацию на детали уведомления
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _autoDeleteRead(NotificationService notificationService) {
    final count = notificationService.autoDeleteableCount;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить прочитанные?'),
        content: Text('Будет удалено $count прочитанных неважных уведомлений.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              notificationService.autoDeleteReadUnimportant();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                AppTheme.successSnackBar('Удалено $count уведомлений'),
              );
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _clearAllNotifications() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Очистить все уведомления?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              context.read<NotificationService>().clearAllNotifications();
              Navigator.of(context).pop();
            },
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Colors.green.shade50;
      case NotificationType.warning:
        return Colors.orange.shade50;
      case NotificationType.error:
        return Colors.red.shade50;
      case NotificationType.info:
      default:
        return Colors.blue.shade50;
    }
  }

  Icon _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return const Icon(Icons.check_circle, color: Colors.green);
      case NotificationType.warning:
        return const Icon(Icons.warning, color: Colors.orange);
      case NotificationType.error:
        return const Icon(Icons.error, color: Colors.red);
      case NotificationType.info:
      default:
        return const Icon(Icons.info, color: Colors.blue);
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) return 'только что';
    if (difference.inMinutes < 60) return '${difference.inMinutes} мин назад';
    if (difference.inHours < 24) return '${difference.inHours} ч назад';
    return '${difference.inDays} дн назад';
  }
}