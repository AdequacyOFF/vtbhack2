import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../models/contact.dart';

class ContactsService {
  static const String _contactsKey = 'contacts';
  final List<Contact> _contacts = [];
  final _uuid = const Uuid();

  // Загрузить контакты из хранилища
  Future<void> loadContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsJson = prefs.getString(_contactsKey);

    if (contactsJson != null) {
      final contactsList = jsonDecode(contactsJson) as List;
      _contacts.clear();
      _contacts.addAll(
        contactsList.map((json) => Contact.fromJson(json)).toList(),
      );
    }
  }

  // Сохранить контакты в хранилище
  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final contactsList = _contacts.map((c) => c.toJson()).toList();
    await prefs.setString(_contactsKey, jsonEncode(contactsList));
  }

  // Получить все контакты
  List<Contact> getAllContacts() {
    return List.unmodifiable(_contacts);
  }

  // Добавить новый контакт
  Future<Contact> addContact({
    required String clientId,
    required String name,
    String? bankCode,
    String? accountId,
  }) async {
    final contact = Contact(
      id: _uuid.v4(),
      clientId: clientId,
      name: name,
      bankCode: bankCode,
      accountId: accountId,
      createdAt: DateTime.now(),
    );

    _contacts.add(contact);
    await _saveContacts();
    return contact;
  }

  // Обновить контакт
  Future<void> updateContact(Contact updatedContact) async {
    final index = _contacts.indexWhere((c) => c.id == updatedContact.id);
    if (index != -1) {
      _contacts[index] = updatedContact;
      await _saveContacts();
    }
  }

  // Удалить контакт
  Future<void> deleteContact(String contactId) async {
    _contacts.removeWhere((c) => c.id == contactId);
    await _saveContacts();
  }

  // Найти контакт по client ID
  Contact? findByClientId(String clientId) {
    try {
      return _contacts.firstWhere((c) => c.clientId == clientId);
    } catch (e) {
      return null;
    }
  }

  // Поиск контактов
  List<Contact> searchContacts(String query) {
    if (query.isEmpty) return getAllContacts();

    final lowerQuery = query.toLowerCase();
    return _contacts.where((contact) {
      return contact.name.toLowerCase().contains(lowerQuery) ||
          contact.clientId.toLowerCase().contains(lowerQuery) ||
          (contact.accountId?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }

  // Проверить существует ли контакт с данным client ID
  bool contactExists(String clientId) {
    return _contacts.any((c) => c.clientId == clientId);
  }

  // Получить количество контактов
  int get contactCount => _contacts.length;

  // Очистить все контакты
  Future<void> clearAllContacts() async {
    _contacts.clear();
    await _saveContacts();
  }
}
