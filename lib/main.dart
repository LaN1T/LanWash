import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'app_styles.dart';
import 'core/service_locator.dart';
import 'providers/auth_provider.dart';
import 'providers/app_provider.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'screens/shared/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/home_shell.dart';
import 'screens/client/client_shell.dart';
import 'screens/washer/washer_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация DI
  setupServiceLocator();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check: в режиме разработки — debug-провайдеры, в релизе — production
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    appleProvider: kReleaseMode
        ? AppleProvider.deviceCheck
        : AppleProvider.appAttestWithDeviceCheckFallback,
  );

  await initializeDateFormatting('ru', null);

  // Инициализация push-уведомлений
  sl<NotificationService>().init().catchError((_) {});

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(
    MultiProvider(
      providers: [
        Provider(
          create: (_) => sl<ApiService>(),
        ),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            api: sl<ApiService>(),
            notifications: sl<NotificationService>(),
          )..init(),
        ),
        ChangeNotifierProvider(
          create: (_) => AppProvider(
            api: sl<ApiService>(),
            notificationService: sl<NotificationService>(),
          ),
        ),
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
          surfaceVariant: AppStyles.bgPage,
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
            fontSize: 17,
            fontWeight: FontWeight.w600,
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
          labelTextStyle: WidgetStateProperty.resolveWith((s) => s
                  .contains(WidgetState.selected)
              ? const TextStyle(
                  color: AppStyles.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)
              : const TextStyle(color: AppStyles.textSecondary, fontSize: 12)),
          iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected)
                  ? AppStyles.primary
                  : AppStyles.textSecondary)),
        ),
        dividerColor: AppStyles.border,
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
              color: AppStyles.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold),
          contentTextStyle:
              TextStyle(color: AppStyles.textSecondary, fontSize: 14),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppStyles.textPrimary,
          contentTextStyle: const TextStyle(color: Colors.white),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          behavior: SnackBarBehavior.floating,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppStyles.primary
                  : Colors.transparent),
          checkColor: WidgetStateProperty.all(Colors.white),
          side: const BorderSide(color: AppStyles.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppStyles.primary
                  : AppStyles.border),
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
                  ? Colors.white
                  : AppStyles.textPrimary),
          dayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
              s.contains(WidgetState.selected)
                  ? AppStyles.primary
                  : Colors.transparent),
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
  @override
  State<_AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<_AppRouter> {
  bool? _wasLoggedIn;
  bool _sessionResumed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      final provider = context.read<AppProvider>();
      if (auth.isLoggedIn) {
        provider.init(auth);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: true);
    final provider = context.read<AppProvider>();

    // При выходе — сбросить данные
    if (_wasLoggedIn == true && !auth.isLoggedIn) {
      _sessionResumed = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.clearData();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }

    // При входе — инициализация
    if (auth.isLoggedIn && _wasLoggedIn != true) {
      _sessionResumed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        provider.init(auth);
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }

    _wasLoggedIn = auth.isLoggedIn;

    if (!auth.initialized) return const SplashScreen();

    // Экран логина: либо вообще не вошли, либо вошли но сессия не продолжена
    if (!auth.isLoggedIn) return const LoginScreen();
    if (auth.isLoggedIn && !_sessionResumed) {
      return LoginScreen(
        onSessionResumed: () => setState(() => _sessionResumed = true),
        isResume: true,
      );
    }

    if (auth.isClient) return ClientShell(key: ClientShell.shellKey);
    if (auth.isWasher) return const WasherShell();
    return const HomeShell();
  }
}
