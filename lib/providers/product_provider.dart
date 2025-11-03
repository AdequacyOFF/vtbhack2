import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../services/auth_service.dart';

class ProductProvider with ChangeNotifier {
  final AuthService _authService;

  Map<String, List<BankProduct>> _productsByBank = {};
  bool _isLoading = false;
  String? _error;

  ProductProvider(this._authService);

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

      for (final bankCode in _authService.supportedBanks) {
        try {
          final service = _authService.getBankService(bankCode);
          final bankProducts = await service.getProducts();
          products[bankCode] = bankProducts;
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

  /// Get best deposit rate
  BankProduct? getBestDeposit({double? amount}) {
    final depositProducts = deposits;
    if (depositProducts.isEmpty) return null;

    // Filter by amount if specified
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

    // Sort by interest rate descending
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

    // Filter by amount if specified
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

    // Sort by interest rate ascending (lowest rate is best for loans)
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

      // Ensure we have product consent
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

      return result;
    } catch (e) {
      throw Exception('Failed to open product: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
