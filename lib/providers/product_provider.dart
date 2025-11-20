import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class ProductProvider with ChangeNotifier {
  final AuthService _authService;
  final NotificationService _notificationService;

  Map<String, List<BankProduct>> _productsByBank = {};
  bool _isLoading = false;
  String? _error;

  ProductProvider(this._authService, this._notificationService);

  Map<String, List<BankProduct>> get productsByBank => _productsByBank;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<BankProduct> get allProducts {
    final products = <BankProduct>[];
    _productsByBank.forEach((bank, productList) {
      products.addAll(productList);
    });
    return products;
  }

  List<BankProduct> get deposits =>
      allProducts.where((p) => p.isDeposit).toList();

  List<BankProduct> get loans =>
      allProducts.where((p) => p.isLoan).toList();

  List<BankProduct> get cards =>
      allProducts.where((p) => p.isCard).toList();

  /// Fetch all products from all banks
  Future<void> fetchAllProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final products = <String, List<BankProduct>>{};

      // Сохраняем предыдущие продукты для сравнения
      final previousProducts = Map<String, List<BankProduct>>.from(_productsByBank);

      for (final bankCode in _authService.supportedBanks) {
        try {
          final service = _authService.getBankService(bankCode);
          final bankProducts = await service.getProducts();
          products[bankCode] = bankProducts;

          // Проверяем новые продукты
          _checkNewProducts(bankCode, bankProducts, previousProducts[bankCode] ?? []);
        } catch (e) {
          debugPrint('Error fetching products from $bankCode: $e');
          products[bankCode] = [];
        }
      }

      _productsByBank = products;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Проверяет новые продукты и создает уведомления
  void _checkNewProducts(String bankCode, List<BankProduct> newProducts, List<BankProduct> previousProducts) {
    final previousIds = previousProducts.map((p) => p.productId).toSet();
    final newOnes = newProducts.where((p) => !previousIds.contains(p.productId)).toList();

    for (final product in newOnes) {
      _notificationService.addNotification(
        title: 'Новый продукт',
        message: '${_getBankName(bankCode)}: ${product.productName}',
        type: NotificationType.info,
      );
    }

    // Уведомление о выгодных продуктах
    _checkBestProducts(bankCode, newProducts);
  }

  /// Проверяет выгодные продукты
  void _checkBestProducts(String bankCode, List<BankProduct> products) {
    final bestDeposit = _findBestDeposit(products);
    final bestLoan = _findBestLoan(products);

    if (bestDeposit != null && (bestDeposit.interestRateValue ?? 0) > 7.0) {
      _notificationService.addNotification(
        title: 'Выгодный вклад',
        message: '${_getBankName(bankCode)}: ${bestDeposit.productName} под ${bestDeposit.interestRateValue}%',
        type: NotificationType.success,
      );
    }

    if (bestLoan != null && (bestLoan.interestRateValue ?? 0) < 12.0) {
      _notificationService.addNotification(
        title: 'Выгодный кредит',
        message: '${_getBankName(bankCode)}: ${bestLoan.productName} под ${bestLoan.interestRateValue}%',
        type: NotificationType.success,
      );
    }
  }

  BankProduct? _findBestDeposit(List<BankProduct> products) {
    final deposits = products.where((p) => p.isDeposit).toList();
    if (deposits.isEmpty) return null;

    deposits.sort((a, b) {
      final rateA = a.interestRateValue ?? 0;
      final rateB = b.interestRateValue ?? 0;
      return rateB.compareTo(rateA);
    });
    return deposits.first;
  }

  BankProduct? _findBestLoan(List<BankProduct> products) {
    final loans = products.where((p) => p.isLoan).toList();
    if (loans.isEmpty) return null;

    loans.sort((a, b) {
      final rateA = a.interestRateValue ?? double.infinity;
      final rateB = b.interestRateValue ?? double.infinity;
      return rateA.compareTo(rateB);
    });
    return loans.first;
  }

  String _getBankName(String bankCode) {
    switch (bankCode) {
      case 'vbank': return 'VBank';
      case 'abank': return 'ABank';
      case 'sbank': return 'SBank';
      case 'babank': return 'Best ADOFF Bank';
      default: return bankCode;
    }
  }

  /// Get best deposit rate
  BankProduct? getBestDeposit({double? amount}) {
    final depositProducts = deposits;
    if (depositProducts.isEmpty) return null;

    final validDeposits = depositProducts.where((p) {
      if (amount != null) {
        final minAmount = p.minAmountValue;
        final maxAmount = p.maxAmountValue;
        if (minAmount != null && amount < minAmount) return false;
        if (maxAmount != null && amount > maxAmount) return false;
      }
      return true;
    }).toList();

    if (validDeposits.isEmpty) return null;

    validDeposits.sort((a, b) {
      final rateA = a.interestRateValue ?? 0;
      final rateB = b.interestRateValue ?? 0;
      return rateB.compareTo(rateA);
    });

    return validDeposits.first;
  }

  /// Get best loan terms (lowest interest rate)
  BankProduct? getBestLoan({double? amount}) {
    final loanProducts = loans;
    if (loanProducts.isEmpty) return null;

    final validLoans = loanProducts.where((p) {
      if (amount != null) {
        final minAmount = p.minAmountValue;
        final maxAmount = p.maxAmountValue;
        if (minAmount != null && amount < minAmount) return false;
        if (maxAmount != null && amount > maxAmount) return false;
      }
      return true;
    }).toList();

    if (validLoans.isEmpty) return null;

    validLoans.sort((a, b) {
      final rateA = a.interestRateValue ?? double.infinity;
      final rateB = b.interestRateValue ?? double.infinity;
      return rateA.compareTo(rateB);
    });

    return validLoans.first;
  }

  /// Open a product (deposit, loan, or card)
  Future<Map<String, dynamic>> openProduct({
    required BankProduct product,
    required double amount,
    int? termMonths,
    String? sourceAccountId,
  }) async {
    try {
      final clientId = _authService.clientId;
      final service = _authService.getBankService(product.bankCode);

      final consent = await _authService.getProductConsent(product.bankCode);

      if (!consent.isApproved) {
        throw Exception('Product consent not approved for ${product.bankCode}');
      }

      final result = await service.openProductAgreement(
        clientId: clientId,
        productId: product.productId,
        amount: amount,
        termMonths: termMonths,
        sourceAccountId: sourceAccountId,
        consentId: consent.consentId,
      );

      // Уведомление об успешном открытии продукта
      _notificationService.addNotification(
        title: 'Продукт открыт',
        message: '${product.productName} на сумму $amount RUB',
        type: NotificationType.success,
      );

      return result;
    } catch (e) {
      _notificationService.addNotification(
        title: 'Ошибка открытия продукта',
        message: 'Не удалось открыть ${product.productName}: $e',
        type: NotificationType.error,
      );
      throw Exception('Failed to open product: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}