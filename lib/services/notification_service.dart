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
  bool isUnread;

  AppNotification({
    required this.title,
    required this.message,
    required this.type,
    DateTime? timestamp,
    String? id,
    this.isUnread = true,
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
  }) {
    _notifications.add(AppNotification(
      title: title,
      message: message,
      type: type,
    ));
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      _notifications[index].isUnread = false;
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
}