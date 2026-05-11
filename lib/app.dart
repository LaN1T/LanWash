import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'config/app_theme.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/app_provider.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home_shell.dart';
import 'presentation/screens/client/client_shell.dart';
import 'presentation/screens/washer/washer_shell.dart';

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
      theme: AppTheme.lightTheme,
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

    debugPrint('[DEBUG] _AppRouter: Build() Auth: loggedIn=${auth.isLoggedIn}, resumed=$_sessionResumed, init=${auth.initialized}');

    if (_wasLoggedIn == true && !auth.isLoggedIn) {
      debugPrint('[DEBUG] _AppRouter: Logout detected, resetting state.');
      _sessionResumed = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.clearData();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
    
    if (auth.isLoggedIn && _wasLoggedIn != true) {
      debugPrint('[DEBUG] _AppRouter: Login detected, initializing provider.');
      _sessionResumed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        provider.init(auth);
        Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }

    _wasLoggedIn = auth.isLoggedIn;
    
    if (!auth.initialized) return const SplashScreen();

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
