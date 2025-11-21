import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yandex_maps_mapkit/init.dart' as yandex_init;

import 'config/app_theme.dart';
import 'config/api_config.dart';
import 'services/auth_service.dart';
import 'services/consent_polling_service.dart';
import 'services/notification_service.dart';
import 'providers/account_provider.dart';
import 'providers/product_provider.dart';
import 'providers/transfer_provider.dart';
import 'providers/news_provider.dart';
import 'providers/virtual_account_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await yandex_init.initMapkit(apiKey: ApiConfig.yandexMapsApiKey);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => AuthService(),
        ),
        ChangeNotifierProvider<NotificationService>(
          create: (_) => NotificationService(),
        ),
        ProxyProvider<AuthService, ConsentPollingService>(
          create: (context) =>
              ConsentPollingService(context.read<AuthService>()),
          update: (context, authService, previous) =>
          previous ?? ConsentPollingService(authService),
          dispose: (_, pollingService) => pollingService.dispose(),
        ),
        ChangeNotifierProxyProvider<AuthService, AccountProvider>(
          create: (context) => AccountProvider(
            context.read<AuthService>(),
            context.read<NotificationService>(),
          ),
          update: (context, authService, previous) =>
          previous ??
              AccountProvider(
                authService,
                context.read<NotificationService>(),
              ),
        ),
        ChangeNotifierProxyProvider<AuthService, ProductProvider>(
          create: (context) => ProductProvider(
            context.read<AuthService>(),
            context.read<NotificationService>(),
          ),
          update: (context, authService, previous) =>
          previous ??
              ProductProvider(
                authService,
                context.read<NotificationService>(),
              ),
        ),
        ChangeNotifierProxyProvider<AuthService, TransferProvider>(
          create: (context) => TransferProvider(
            context.read<AuthService>(),
            context.read<NotificationService>(),
          ),
          update: (context, authService, previous) =>
          previous ??
              TransferProvider(
                authService,
                context.read<NotificationService>(),
              ),
        ),
        ChangeNotifierProvider<NewsProvider>(
          create: (_) => NewsProvider(),
        ),
        ChangeNotifierProxyProvider<NotificationService,
            VirtualAccountProvider>(
          create: (context) => VirtualAccountProvider(
            context.read<NotificationService>(),
          ),
          update: (context, notificationService, previous) =>
          previous ?? VirtualAccountProvider(notificationService),
        ),
      ],
      child: MaterialApp(
        title: 'Multi-Bank App',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const AppInitializer(),
        builder: (context, child) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              final currentFocus = FocusScope.of(context);
              if (!currentFocus.hasPrimaryFocus &&
                  currentFocus.focusedChild != null) {
                currentFocus.unfocus();
              }
            },
            child: child,
          );
        },
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isInitialized = false;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final authService = context.read<AuthService>();
    await authService.initialize();

    setState(() {
      _isAuthenticated = authService.isAuthenticated;
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return _isAuthenticated ? const HomeScreen() : const LoginScreen();
  }
}
