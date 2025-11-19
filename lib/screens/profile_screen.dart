import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../providers/account_provider.dart';
import '../services/pdf_service.dart';
import '../services/analytics_service.dart';
import '../config/app_theme.dart';
import 'login_screen.dart';
import 'consent_management_screen.dart';
import 'pdf_viewer_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 110,
        ),
        children: [
          const SizedBox(height: 16),
          Container(
            decoration: AppTheme.modernCardDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: 24,
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 26,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.55),
                              width: 1.6,
                            ),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.22),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.person_rounded,
                                size: 40,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 6,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.26),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 14,
                                  color: AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'AI',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryBlue,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.verified_rounded,
                        size: 18,
                        color: AppTheme.successGreen,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Подписка активирована',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.successGreen,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    authService.clientId,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Пользователь Multi-Bank App',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            context,
            icon: Icons.admin_panel_settings,
            title: 'Управление согласиями',
            subtitle: 'Просмотр и создание согласий для банков',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConsentManagementScreen(),
                ),
              );
            },
          ),
          _buildActionCard(
            context,
            icon: Icons.picture_as_pdf,
            title: 'Выгрузить выписку в PDF',
            subtitle: 'Создать PDF со всеми счетами и транзакциями',
            onTap: () => _generatePdf(context),
          ),
          _buildActionCard(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Основной счёт для списания',
            subtitle: 'Выберите, с какого счёта платить по умолчанию',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrimaryAccountSelectionScreen(),
                ),
              );
            },
          ),
          _buildActionCard(
            context,
            icon: Icons.auto_awesome_rounded,
            title: 'Интересующие категории',
            subtitle: 'Настройте рекомендации и кешбеки под себя',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CategoryInterestsScreen(),
                ),
              );
            },
          ),
          _buildActionCard(
            context,
            icon: Icons.link,
            title: 'Связать соцсети',
            subtitle: 'Переводы по никнейму',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Функция в разработке')),
              );
            },
          ),
          _buildActionCard(
            context,
            icon: Icons.add_card,
            title: 'Открыть счет в партнерском банке',
            subtitle: 'Используя данные текущих счетов',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Функция в разработке')),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _logout(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.modernCardDecoration(borderRadius: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: AppTheme.textSecondary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context) async {
    final accountProvider = context.read<AccountProvider>();

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Генерация PDF...')),
      );

      final file = await PdfService.generateAccountStatement(
        accounts: accountProvider.accounts,
        transactionsByAccount: accountProvider.transactions,
        balances: accountProvider.balances,
      );

      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successGreen,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('PDF создан'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Выберите действие:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Файл: ${file.path.split('/').last}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  PdfService.sharePdf(file);
                },
                icon: const Icon(Icons.share_rounded),
                label: const Text('Поделиться'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PdfViewerScreen(
                        filePath: file.path,
                        title: 'Выписка по счетам',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Открыть'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выход'),
        content: const Text('Вы уверены, что хотите выйти?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<AuthService>().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
        );
      }
    }
  }
}

class PrimaryAccountSelectionScreen extends StatelessWidget {
  const PrimaryAccountSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final accountProvider = context.watch<AccountProvider>();
    final accounts = accountProvider.accounts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Основной счёт'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
      ),
      body: accounts.isEmpty
          ? const Center(
        child: Text(
          'Счета не найдены',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: accounts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final account = accounts[index];

          return Container(
            decoration: AppTheme.modernCardDecoration(
              borderRadius: 20,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: AppTheme.accentGradient,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                ),
              ),
              title: Text(
                account.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              subtitle: const Text(
                'Нажмите, чтобы сделать основным',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Логика выбора будет добавлена позже',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CategoryGroup {
  final String title;
  final List<String> subcategories;

  const _CategoryGroup(this.title, this.subcategories);
}

const List<_CategoryGroup> _categoryGroups = [
  _CategoryGroup('Продукты', [
    'Супермаркеты / гипермаркеты',
    'Магазины у дома',
    'Рынки / фермерские лавки',
    'Пекарни',
    'Магазины воды и напитков',
  ]),
  _CategoryGroup('Кафе и рестораны', [
    'Кафе / кофейни',
    'Рестораны',
    'Фастфуд',
    'Доставка еды',
    'Стритфуд',
  ]),
  _CategoryGroup('Транспорт (городской)', [
    'Общественный транспорт',
    'Такси',
    'Каршеринг',
    'Прокат самокатов',
    'Прокат велосипедов',
  ]),
  _CategoryGroup('Авто: топливо и сервис', [
    'АЗС',
    'Автомойки',
    'Шиномонтаж',
    'СТО / ремонт',
    'Парковки',
    'Платные дороги',
  ]),
  _CategoryGroup('Связь и интернет', [
    'Мобильная связь',
    'Домашний интернет',
    'ТВ / кабельное',
    'Пакеты связи (комбо-тарифы)',
  ]),
  _CategoryGroup('Цифровые сервисы и подписки', [
    'Видеосервисы',
    'Музыкальные сервисы',
    'Облачные хранилища',
    'VPN и безопасность',
    'Игровые подписки',
    'Платные приложения и сервисы',
  ]),
  _CategoryGroup('Одежда, обувь и шопинг', [
    'Одежда',
    'Обувь',
    'Аксессуары',
    'Маркетплейсы',
    'ТЦ и мультибрендовые магазины',
  ]),
  _CategoryGroup('Бытовая техника и электроника', [
    'Смартфоны и гаджеты',
    'Компьютеры и ноутбуки',
    'ТВ и аудио',
    'Крупная бытовая техника',
    'Мелкая бытовая техника',
    'Умный дом',
  ]),
  _CategoryGroup('Дом, ремонт и мебель', [
    'Стройматериалы',
    'Инструменты',
    'Мебель',
    'Освещение',
    'Декор и текстиль',
    'Сад и огород',
  ]),
  _CategoryGroup('Здоровье и аптеки', [
    'Аптеки',
    'Клиники и лаборатории',
    'Стоматология',
    'Оптика',
    'Медстрахование',
  ]),
  _CategoryGroup('Красота и уход', [
    'Парикмахерские / барбершопы',
    'Маникюр / педикюр',
    'Салоны красоты / косметология',
    'Косметика и уход',
    'Парфюмерия',
  ]),
  _CategoryGroup('Спорт и фитнес', [
    'Фитнес-клубы и залы',
    'Студии (йога, танцы и т.п.)',
    'Спортивное питание',
    'Спортивная одежда и обувь',
    'Спортивный инвентарь',
  ]),
  _CategoryGroup('Развлечения и досуг', [
    'Кино',
    'Театр и концерты',
    'Музеи и выставки',
    'Парки развлечений',
    'Игровые магазины и онлайн-игры',
    'Хобби-магазины',
  ]),
  _CategoryGroup('Путешествия', [
    'Авиабилеты',
    'ЖД / автобусы дальние',
    'Отели и апартаменты',
    'Туроператоры и турпакеты',
    'Аренда авто в поездке',
    'Экскурсии и активности',
  ]),
  _CategoryGroup('Дети и семья', [
    'Детская одежда и обувь',
    'Детские магазины и игрушки',
    'Детские товары (коляски, автокресла и т.п.)',
    'Кружки и секции',
    'Детские мероприятия и развлечения',
  ]),
  _CategoryGroup('Домашние животные', [
    'Корм',
    'Аксессуары и товары для животных',
    'Ветклиники',
    'Груминг',
  ]),
  _CategoryGroup('Подарки и цветы', [
    'Цветочные магазины',
    'Подарочные магазины',
    'Сувениры',
    'Праздничные товары и декор',
  ]),
];

class CategoryInterestsScreen extends StatefulWidget {
  const CategoryInterestsScreen({super.key});

  @override
  State<CategoryInterestsScreen> createState() =>
      _CategoryInterestsScreenState();
}

class _CategoryInterestsScreenState extends State<CategoryInterestsScreen> {
  final Set<String> _selected = <String>{};
  static const _prefsKey = 'selected_categories';

  int get _totalSubcategories =>
      _categoryGroups.fold<int>(0, (sum, g) => sum + g.subcategories.length);

  @override
  void initState() {
    super.initState();
    _loadSelected();
  }

  Future<void> _loadSelected() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? <String>[];
    setState(() {
      _selected
        ..clear()
        ..addAll(saved);
    });
  }

  Future<void> _saveSelected() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _selected.toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Интересующие категории'),
        backgroundColor: AppTheme.primaryBlue,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Container(
                      decoration: AppTheme.modernCardDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: 24,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_rounded,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Выберите интересующее, '
                                        'чтобы наш ИИ помогал и подсказывал',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Чем больше выберете, тем точнее будут '
                                        'рекомендации по тратам и кешбекам.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.3,
                                      color: Colors.white.withValues(
                                        alpha: 0.9,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.18),
                                          borderRadius:
                                          BorderRadius.circular(999),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.check_circle_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Выбрано: ${_selected.length}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'всего $_totalSubcategories',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, index) {
                        final group = _categoryGroups[index];
                        final groupSelectedCount = group.subcategories
                            .where(_selected.contains)
                            .length;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            decoration: AppTheme.modernCardDecoration(
                              borderRadius: 22,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                14,
                                16,
                                12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          group.title,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                      ),
                                      AnimatedOpacity(
                                        opacity:
                                        groupSelectedCount > 0 ? 1 : 0,
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius:
                                            BorderRadius.circular(999),
                                            color: AppTheme.primaryBlue
                                                .withValues(alpha: 0.08),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.check_rounded,
                                                size: 14,
                                                color: AppTheme.primaryBlue,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '$groupSelectedCount',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color:
                                                  AppTheme.primaryBlue,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      for (final sub in group.subcategories)
                                        _buildChip(sub),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: _categoryGroups.length,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 180),
                    opacity: _selected.isEmpty ? 1 : 0,
                    child: const Text(
                      'Выберите хотя бы пару категорий — '
                          'ИИ будет давать более понятные подсказки.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty) ...[
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 180),
                      opacity: 1,
                      child: Text(
                        'Отлично, уже выбрано ${_selected.length} категорий',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await _saveSelected();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Row(
                            children: const [
                              Icon(
                                Icons.check_circle_rounded,
                                color: AppTheme.successGreen,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Предпочтения успешно сохранены',
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Готово',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final isSelected = _selected.contains(label);

    final textStyle = isSelected
        ? const TextStyle(
      color: Colors.white,
      fontWeight: FontWeight.w600,
      fontSize: 13,
    )
        : const TextStyle(
      color: AppTheme.textPrimary,
      fontWeight: FontWeight.w500,
      fontSize: 13,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () {
        setState(() {
          if (isSelected) {
            _selected.remove(label);
          } else {
            _selected.add(label);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: isSelected ? AppTheme.accentGradient : null,
          color: isSelected
              ? null
              : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : AppTheme.primaryBlue.withValues(alpha: 0.35),
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_rounded : Icons.add_rounded,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.primaryBlue,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: textStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
