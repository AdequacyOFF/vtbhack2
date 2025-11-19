class VirtualAccount {
  final String id;
  final String category;
  final double allocatedAmount;
  final double spentAmount;
  final String monthYear; // Format: "2025-01" for tracking monthly reset
  final DateTime createdAt;

  VirtualAccount({
    required this.id,
    required this.category,
    required this.allocatedAmount,
    required this.spentAmount,
    required this.monthYear,
    required this.createdAt,
  });

  double get remainingAmount => allocatedAmount - spentAmount;
  double get spentPercentage => allocatedAmount > 0 ? (spentAmount / allocatedAmount * 100) : 0;
  bool get isExhausted => remainingAmount <= 0;

  VirtualAccount copyWith({
    String? id,
    String? category,
    double? allocatedAmount,
    double? spentAmount,
    String? monthYear,
    DateTime? createdAt,
  }) {
    return VirtualAccount(
      id: id ?? this.id,
      category: category ?? this.category,
      allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      spentAmount: spentAmount ?? this.spentAmount,
      monthYear: monthYear ?? this.monthYear,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'allocated_amount': allocatedAmount,
      'spent_amount': spentAmount,
      'month_year': monthYear,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory VirtualAccount.fromJson(Map<String, dynamic> json) {
    return VirtualAccount(
      id: json['id'] ?? '',
      category: json['category'] ?? '',
      allocatedAmount: (json['allocated_amount'] ?? 0).toDouble(),
      spentAmount: (json['spent_amount'] ?? 0).toDouble(),
      monthYear: json['month_year'] ?? '',
      createdAt: DateTime.parse(json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  // Get current month-year string
  static String getCurrentMonthYear() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }
}

// Common expense categories
class ExpenseCategory {
  static const String food = 'Еда';
  static const String transport = 'Транспорт';
  static const String shopping = 'Покупки';
  static const String entertainment = 'Развлечения';
  static const String health = 'Здоровье';
  static const String utilities = 'Коммунальные услуги';
  static const String education = 'Образование';
  static const String other = 'Другое';

  static const List<String> all = [
    food,
    transport,
    shopping,
    entertainment,
    health,
    utilities,
    education,
    other,
  ];

  // Map API merchant category to virtual account category
  static String? mapMerchantCategory(String? merchantCategory) {
    if (merchantCategory == null) return null;

    final category = merchantCategory.toLowerCase();

    // Map API categories to our categories
    if (category == 'food' || category == 'restaurant' || category == 'dining') {
      return food;
    } else if (category == 'transport' || category == 'transportation') {
      return transport;
    } else if (category == 'shopping' || category == 'clothing' || category == 'retail') {
      return shopping;
    } else if (category == 'entertainment' || category == 'recreation') {
      return entertainment;
    } else if (category == 'health' || category == 'medical') {
      return health;
    } else if (category == 'utilities' || category == 'telecom') {
      return utilities;
    } else if (category == 'education') {
      return education;
    }

    return other;
  }

  // Map transaction categories to virtual account categories (legacy keyword-based)
  static String? mapTransactionCategory(String? transactionCategory) {
    if (transactionCategory == null) return null;

    final category = transactionCategory.toLowerCase();

    // Food & Restaurants
    if (category.contains('food') || category.contains('еда') ||
        category.contains('restaurant') || category.contains('ресторан') ||
        category.contains('cafe') || category.contains('кафе') ||
        category.contains('dining') || category.contains('питание') ||
        category.contains('groceries') || category.contains('продукты') ||
        category.contains('supermarket') || category.contains('супермаркет')) {
      return food;
    }

    // Transport
    else if (category.contains('transport') || category.contains('транспорт') ||
               category.contains('taxi') || category.contains('такси') ||
               category.contains('fuel') || category.contains('топливо') ||
               category.contains('gas') || category.contains('бензин') ||
               category.contains('parking') || category.contains('парковка') ||
               category.contains('metro') || category.contains('метро') ||
               category.contains('bus') || category.contains('автобус')) {
      return transport;
    }

    // Shopping & Clothing
    else if (category.contains('shopping') || category.contains('покупки') ||
               category.contains('retail') || category.contains('магазин') ||
               category.contains('clothing') || category.contains('одежда') ||
               category.contains('clothes') || category.contains('apparel') ||
               category.contains('fashion') || category.contains('мода') ||
               category.contains('shoes') || category.contains('обувь') ||
               category.contains('accessories') || category.contains('аксессуары')) {
      return shopping;
    }

    // Entertainment
    else if (category.contains('entertainment') || category.contains('развлечения') ||
               category.contains('cinema') || category.contains('кино') ||
               category.contains('games') || category.contains('игры') ||
               category.contains('movie') || category.contains('фильм') ||
               category.contains('theater') || category.contains('театр') ||
               category.contains('concert') || category.contains('концерт') ||
               category.contains('sport') || category.contains('спорт') ||
               category.contains('gym') || category.contains('фитнес')) {
      return entertainment;
    }

    // Health
    else if (category.contains('health') || category.contains('здоровье') ||
               category.contains('medical') || category.contains('медицина') ||
               category.contains('pharmacy') || category.contains('аптека') ||
               category.contains('doctor') || category.contains('врач') ||
               category.contains('hospital') || category.contains('больница') ||
               category.contains('clinic') || category.contains('клиника')) {
      return health;
    }

    // Utilities
    else if (category.contains('utilities') || category.contains('коммунальные') ||
               category.contains('bills') || category.contains('счета') ||
               category.contains('electricity') || category.contains('электричество') ||
               category.contains('water') || category.contains('вода') ||
               category.contains('internet') || category.contains('интернет') ||
               category.contains('phone') || category.contains('телефон')) {
      return utilities;
    }

    // Education
    else if (category.contains('education') || category.contains('образование') ||
               category.contains('school') || category.contains('школа') ||
               category.contains('university') || category.contains('университет') ||
               category.contains('course') || category.contains('курс') ||
               category.contains('training') || category.contains('обучение') ||
               category.contains('book') || category.contains('книга')) {
      return education;
    }

    return other;
  }

  // Get icon for category
  static String getIcon(String category) {
    switch (category) {
      case food:
        return '🍽️';
      case transport:
        return '🚗';
      case shopping:
        return '🛍️';
      case entertainment:
        return '🎬';
      case health:
        return '💊';
      case utilities:
        return '💡';
      case education:
        return '📚';
      case other:
      default:
        return '💰';
    }
  }
}
