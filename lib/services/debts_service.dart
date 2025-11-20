import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/debt.dart';

class DebtsService {
  static const String _debtsKey = 'debts';
  final List<Debt> _debts = [];
  final _uuid = const Uuid();

  // Загрузить долги из хранилища
  Future<void> loadDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final debtsJson = prefs.getString(_debtsKey);

    if (debtsJson != null) {
      final debtsList = jsonDecode(debtsJson) as List;
      _debts.clear();
      _debts.addAll(
        debtsList.map((json) => Debt.fromJson(json)).toList(),
      );
    }
  }

  // Сохранить долги в хранилище
  Future<void> _saveDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final debtsList = _debts.map((d) => d.toJson()).toList();
    await prefs.setString(_debtsKey, jsonEncode(debtsList));
  }

  // Получить все долги
  List<Debt> getAllDebts() {
    return List.unmodifiable(_debts);
  }

  // Добавить новый долг
  Future<Debt> addDebt({
    required String contactId,
    required String contactName,
    required String contactClientId,
    required double amount,
    String currency = 'RUB',
    required DebtType type,
    DateTime? returnDate,
    String? comment,
  }) async {
    final debt = Debt(
      id: _uuid.v4(),
      contactId: contactId,
      contactName: contactName,
      contactClientId: contactClientId,
      amount: amount,
      currency: currency,
      type: type,
      createdAt: DateTime.now(),
      returnDate: returnDate,
      comment: comment,
      isReturned: false,
    );

    _debts.add(debt);
    await _saveDebts();
    return debt;
  }

  // Обновить долг
  Future<void> updateDebt(Debt updatedDebt) async {
    final index = _debts.indexWhere((d) => d.id == updatedDebt.id);
    if (index != -1) {
      _debts[index] = updatedDebt;
      await _saveDebts();
    }
  }

  // Отметить долг как возвращенный
  Future<void> markAsReturned(String debtId) async {
    final index = _debts.indexWhere((d) => d.id == debtId);
    if (index != -1) {
      _debts[index] = _debts[index].copyWith(isReturned: true);
      await _saveDebts();
    }
  }

  // Удалить долг
  Future<void> deleteDebt(String debtId) async {
    _debts.removeWhere((d) => d.id == debtId);
    await _saveDebts();
  }

  // Получить долги где Я должен (не возвращенные)
  List<Debt> getMyDebts({bool includeReturned = false}) {
    return _debts
        .where((d) =>
            d.type == DebtType.iOwe && (includeReturned || !d.isReturned))
        .toList()
      ..sort((a, b) {
        if (a.isOverdue != b.isOverdue) {
          return a.isOverdue ? -1 : 1; // Просроченные сначала
        }
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  // Получить долги где Мне должны (не возвращенные)
  List<Debt> getDebtsToMe({bool includeReturned = false}) {
    return _debts
        .where((d) =>
            d.type == DebtType.owedToMe &&
            (includeReturned || !d.isReturned))
        .toList()
      ..sort((a, b) {
        if (a.isOverdue != b.isOverdue) {
          return a.isOverdue ? -1 : 1; // Просроченные сначала
        }
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  // Получить просроченные долги
  List<Debt> getOverdueDebts() {
    return _debts.where((d) => !d.isReturned && d.isOverdue).toList()
      ..sort((a, b) => a.returnDate!.compareTo(b.returnDate!));
  }

  // Получить долги с приближающимся сроком возврата (следующие 7 дней)
  List<Debt> getUpcomingDebts() {
    final now = DateTime.now();
    final weekLater = now.add(const Duration(days: 7));

    return _debts.where((d) {
      if (d.isReturned || d.returnDate == null) return false;
      return d.returnDate!.isAfter(now) && d.returnDate!.isBefore(weekLater);
    }).toList()
      ..sort((a, b) => a.returnDate!.compareTo(b.returnDate!));
  }

  // Получить долги по контакту
  List<Debt> getDebtsByContact(String contactId,
      {bool includeReturned = false}) {
    return _debts
        .where((d) =>
            d.contactId == contactId && (includeReturned || !d.isReturned))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Получить общую сумму долгов где Я должен
  double getTotalIOwe() {
    return _debts
        .where((d) => d.type == DebtType.iOwe && !d.isReturned)
        .fold(0.0, (sum, debt) => sum + debt.amount);
  }

  // Получить общую сумму долгов где Мне должны
  double getTotalOwedToMe() {
    return _debts
        .where((d) => d.type == DebtType.owedToMe && !d.isReturned)
        .fold(0.0, (sum, debt) => sum + debt.amount);
  }

  // Получить количество активных долгов
  int get activeDebtsCount =>
      _debts.where((d) => !d.isReturned).length;

  // Получить количество просроченных долгов
  int get overdueDebtsCount => getOverdueDebts().length;

  // Очистить все долги
  Future<void> clearAllDebts() async {
    _debts.clear();
    await _saveDebts();
  }
}
