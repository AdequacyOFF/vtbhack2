import 'package:flutter/foundation.dart';

enum NotificationType {
  info,
  success,
  warning,
  error,
}

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isImportant;
  bool isUnread;

  AppNotification({
    required this.title,
    required this.message,
    required this.type,
    DateTime? timestamp,
    String? id,
    this.isUnread = true,
    this.isImportant = false,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp = timestamp ?? DateTime.now();
}

class NotificationService extends ChangeNotifier {
  final List<AppNotification> _notifications = [];

  List<AppNotification> get notifications => _notifications.reversed.toList();

  int get unreadCount => _notifications.where((n) => n.isUnread).length;

  void addNotification({
    required String title,
    required String message,
    NotificationType type = NotificationType.info,
    bool isImportant = false,
  }) {
    _notifications.add(AppNotification(
      title: title,
      message: message,
      type: type,
      isImportant: isImportant,
    ));
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isUnread = false;

      // Auto-delete unimportant notifications after marking as read
      if (!_notifications[index].isImportant) {
        // Remove after 2 seconds to allow user to see the change
        Future.delayed(const Duration(seconds: 2), () {
          _notifications.removeWhere((n) => n.id == id);
          notifyListeners();
        });
      }

      notifyListeners();
    }
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clearAllNotifications() {
    _notifications.clear();
    notifyListeners();
  }

  // Auto-delete all read unimportant notifications
  void autoDeleteReadUnimportant() {
    _notifications.removeWhere((n) => !n.isUnread && !n.isImportant);
    notifyListeners();
  }

  // Get count of notifications that can be auto-deleted
  int get autoDeleteableCount =>
      _notifications.where((n) => !n.isUnread && !n.isImportant).length;
}