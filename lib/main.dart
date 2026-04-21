import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app_styles.dart';
import 'providers/auth_provider.dart';
import 'providers/app_provider.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';
import 'screens/home_shell.dart';
import 'screens/client/client_shell.dart';
import 'screens/washer/washer_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru', null);
  
  // Инициализация уведомлений
  await NotificationService().init();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => AppProvider()..init()),
      ],
      child: const LanWashApp(),
    ),
  );
}

class LanWashApp extends StatelessWidget {
  const LanWashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LanWash',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [Locale('ru', 'RU')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: AppStyles.primary,
          secondary: AppStyles.primaryLight,
          surface: AppStyles.bgCard,
          background: AppStyles.bgPage,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppStyles.bgPage,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppStyles.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: AppStyles.textPrimary,
            fontSize: 17, fontWeight: FontWeight.w600,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppStyles.border),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: AppStyles.primaryBg,
          labelTextStyle: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
              ? const TextStyle(color: AppStyles.primary, fontSize: 12,
                  fontWeight: FontWeight.w600)
              : const TextStyle(color: AppStyles.textSecondary, fontSize: 12)),
          iconTheme: WidgetStateProperty.resolveWith((s) =>
            IconThemeData(color: s.contains(WidgetState.selected)
              ? AppStyles.primary : AppStyles.textSecondary)),
        ),
        dividerColor: AppStyles.border,
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(color: AppStyles.textPrimary,
              fontSize: 18, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: AppStyles.textSecondary,
              fontSize: 14),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppStyles.textPrimary,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppStyles.primary : Colors.transparent),
          checkColor: WidgetStateProperty.all(Colors.white),
          side: const BorderSide(color: AppStyles.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? AppStyles.primary : AppStyles.border),
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: AppStyles.primary,
          unselectedLabelColor: AppStyles.textSecondary,
          indicatorColor: AppStyles.primary,
          dividerColor: AppStyles.border,
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppStyles.primary,
          foregroundColor: Colors.white,
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          headerBackgroundColor: AppStyles.primary,
          headerForegroundColor: Colors.white,
          dayForegroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Colors.white : AppStyles.textPrimary),
          dayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppStyles.primary : Colors.transparent),
          todayForegroundColor: WidgetStateProperty.all(AppStyles.primary),
          todayBackgroundColor: WidgetStateProperty.all(AppStyles.primaryBg),
        ),
      ),
      home: const _AppRouter(),
    );
  }
}

class _AppRouter extends StatefulWidget {
  const _AppRouter();
  @override State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool? _wasLoggedIn;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final provider = context.read<AppProvider>();
      
      provider.startAutoRefresh(auth);
      auth.addListener(() {
        provider.startAutoRefresh(auth);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final provider = context.read<AppProvider>();

    // При выходе — сбросить данные провайдера
    if (_wasLoggedIn == true && !auth.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.clearData();
        provider.init(); // перезагрузить список услуг (без фильтрации)
      });
    }
    // При входе админа — загружаем все записи и заметки
    if (_wasLoggedIn == false && auth.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.reloadAppointments();
        provider.refreshUnreadCount();
      });
    }
    _wasLoggedIn = auth.isLoggedIn;

    if (!auth.initialized) {
      return const Scaffold(
        backgroundColor: AppStyles.bgPage,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_car_wash, color: AppStyles.primary, size: 64),
          SizedBox(height: 16),
          Text('LanWash', style: TextStyle(
            color: AppStyles.textPrimary, fontSize: 28,
            fontWeight: FontWeight.bold,
          )),
          SizedBox(height: 16),
          CircularProgressIndicator(color: AppStyles.primary),
        ])),
      );
    }

    if (!auth.isLoggedIn) return const LoginScreen();
    if (auth.isClient)   return ClientShell(key: ClientShell.shellKey);
    if (auth.isWasher)   return const WasherShell();
    return const HomeShell();
  }
}
