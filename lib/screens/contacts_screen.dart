import 'package:flutter/material.dart';
import '../models/contact.dart';
import '../services/contacts_service.dart';
import '../config/app_theme.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final ContactsService _contactsService = ContactsService();
  List<Contact> _contacts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    setState(() => _isLoading = true);
    await _contactsService.loadContacts();
    setState(() {
      _contacts = _contactsService.getAllContacts();
      _isLoading = false;
    });
  }

  List<Contact> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    return _contactsService.searchContacts(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Контакты'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddContactDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Поиск контактов...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),

          // Contacts List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredContacts.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _filteredContacts[index];
                          return _buildContactCard(contact);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.contacts_outlined,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'Нет сохраненных контактов'
                : 'Контакты не найдены',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            Text(
              'Добавьте контакты для быстрых переводов',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty)
            ElevatedButton.icon(
              onPressed: () => _showAddContactDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Добавить контакт'),
            ),
        ],
      ),
    );
  }

  Widget _buildContactCard(Contact contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.accentBlue,
          child: Text(
            contact.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          contact.displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('ID: ${contact.clientId}'),
            if (contact.bankCode != null || contact.accountId != null)
              Text(
                contact.description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _showEditContactDialog(contact);
            } else if (value == 'delete') {
              _showDeleteConfirmation(contact);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 8),
                  Text('Редактировать'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: AppTheme.errorRed),
                  SizedBox(width: 8),
                  Text('Удалить', style: TextStyle(color: AppTheme.errorRed)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddContactDialog() async {
    final clientIdController = TextEditingController();
    final nameController = TextEditingController();
    final accountIdController = TextEditingController();
    String? selectedBank;

    final banks = ['vbank', 'abank', 'sbank'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Добавить контакт'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя контакта *',
                    prefixIcon: Icon(Icons.person),
                    hintText: 'Например: Иван Иванов',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: clientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Client ID *',
                    prefixIcon: Icon(Icons.badge),
                    hintText: 'team201-1',
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedBank,
                  decoration: const InputDecoration(
                    labelText: 'Банк (необязательно)',
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  items: banks.map<DropdownMenuItem<String>>((bank) {
                    return DropdownMenuItem<String>(
                      value: bank,
                      child: Text(bank.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedBank = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: accountIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID счета (необязательно)',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    clientIdController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните обязательные поля')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      await _contactsService.addContact(
        clientId: clientIdController.text.trim(),
        name: nameController.text.trim(),
        bankCode: selectedBank,
        accountId: accountIdController.text.trim().isNotEmpty
            ? accountIdController.text.trim()
            : null,
      );
      _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Контакт добавлен')),
        );
      }
    }
  }

  Future<void> _showEditContactDialog(Contact contact) async {
    final clientIdController = TextEditingController(text: contact.clientId);
    final nameController = TextEditingController(text: contact.name);
    final accountIdController = TextEditingController(text: contact.accountId ?? '');
    String? selectedBank = contact.bankCode;

    final banks = ['vbank', 'abank', 'sbank'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Редактировать контакт'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Имя контакта *',
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: clientIdController,
                  decoration: const InputDecoration(
                    labelText: 'Client ID *',
                    prefixIcon: Icon(Icons.badge),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedBank,
                  decoration: const InputDecoration(
                    labelText: 'Банк (необязательно)',
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  items: banks.map<DropdownMenuItem<String>>((bank) {
                    return DropdownMenuItem<String>(
                      value: bank,
                      child: Text(bank.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedBank = value);
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: accountIdController,
                  decoration: const InputDecoration(
                    labelText: 'ID счета (необязательно)',
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty ||
                    clientIdController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните обязательные поля')),
                  );
                  return;
                }
                Navigator.of(context).pop(true);
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final updatedContact = Contact(
        id: contact.id,
        clientId: clientIdController.text.trim(),
        name: nameController.text.trim(),
        bankCode: selectedBank,
        accountId: accountIdController.text.trim().isNotEmpty
            ? accountIdController.text.trim()
            : null,
        createdAt: contact.createdAt,
      );
      await _contactsService.updateContact(updatedContact);
      _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Контакт обновлен')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(Contact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить контакт?'),
        content: Text('Вы уверены, что хотите удалить "${contact.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _contactsService.deleteContact(contact.id);
      _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Контакт удален')),
        );
      }
    }
  }
}
