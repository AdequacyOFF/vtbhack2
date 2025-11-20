class Debt {
  final String id; // Уникальный ID долга
  final String contactId; // ID контакта (связь с Contact)
  final String contactName; // Имя контакта
  final String contactClientId; // Client ID контакта
  final double amount; // Сумма долга
  final String currency; // Валюта (обычно RUB)
  final DebtType type; // Я должен (IOwе) или Мне должны (OwedToMe)
  final DateTime createdAt; // Дата создания долга
  final DateTime? returnDate; // Дата возврата
  final String? comment; // Комментарий к долгу
  final bool isReturned; // Возвращен ли долг

  Debt({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.contactClientId,
    required this.amount,
    this.currency = 'RUB',
    required this.type,
    required this.createdAt,
    this.returnDate,
    this.comment,
    this.isReturned = false,
  });

  factory Debt.fromJson(Map<String, dynamic> json) {
    return Debt(
      id: json['id'] ?? '',
      contactId: json['contact_id'] ?? '',
      contactName: json['contact_name'] ?? '',
      contactClientId: json['contact_client_id'] ?? '',
      amount: (json['amount'] is String)
          ? double.tryParse(json['amount']) ?? 0.0
          : (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] ?? 'RUB',
      type: DebtType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => DebtType.iOwe,
      ),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      returnDate: json['return_date'] != null
          ? DateTime.parse(json['return_date'])
          : null,
      comment: json['comment'],
      isReturned: json['is_returned'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contact_id': contactId,
      'contact_name': contactName,
      'contact_client_id': contactClientId,
      'amount': amount,
      'currency': currency,
      'type': type.toString().split('.').last,
      'created_at': createdAt.toIso8601String(),
      'return_date': returnDate?.toIso8601String(),
      'comment': comment,
      'is_returned': isReturned,
    };
  }

  // Отформатированная сумма
  String get formattedAmount {
    return '${amount.toStringAsFixed(2)} $currency';
  }

  // Просрочен ли долг
  bool get isOverdue {
    if (isReturned || returnDate == null) return false;
    return DateTime.now().isAfter(returnDate!);
  }

  // Сколько дней осталось до возврата
  int? get daysUntilReturn {
    if (returnDate == null || isReturned) return null;
    final diff = returnDate!.difference(DateTime.now()).inDays;
    return diff;
  }

  // Описание статуса
  String get statusDescription {
    if (isReturned) return 'Возвращен';
    if (isOverdue) return 'Просрочен';
    if (daysUntilReturn != null) {
      if (daysUntilReturn! == 0) return 'Сегодня';
      if (daysUntilReturn! == 1) return 'Завтра';
      if (daysUntilReturn! < 0) return 'Просрочен на ${-daysUntilReturn!} дн.';
      return 'Через ${daysUntilReturn!} дн.';
    }
    return 'Без срока';
  }

  // Копия с изменениями
  Debt copyWith({
    String? id,
    String? contactId,
    String? contactName,
    String? contactClientId,
    double? amount,
    String? currency,
    DebtType? type,
    DateTime? createdAt,
    DateTime? returnDate,
    String? comment,
    bool? isReturned,
  }) {
    return Debt(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      contactClientId: contactClientId ?? this.contactClientId,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      returnDate: returnDate ?? this.returnDate,
      comment: comment ?? this.comment,
      isReturned: isReturned ?? this.isReturned,
    );
  }
}

// Тип долга
enum DebtType {
  iOwe, // Я должен (я взял в долг)
  owedToMe, // Мне должны (я дал в долг)
}

extension DebtTypeExtension on DebtType {
  String get displayName {
    switch (this) {
      case DebtType.iOwe:
        return 'Я должен';
      case DebtType.owedToMe:
        return 'Мне должны';
    }
  }

  String get shortName {
    switch (this) {
      case DebtType.iOwe:
        return 'Долг';
      case DebtType.owedToMe:
        return 'Займ';
    }
  }
}
