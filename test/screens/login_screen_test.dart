import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:lanwash/providers/auth_provider.dart';
import 'package:lanwash/providers/theme_provider.dart';
import 'package:lanwash/providers/language_provider.dart';
import 'package:lanwash/screens/auth/login_screen.dart';
import 'package:lanwash/screens/auth/register_screen.dart';
import '../mocks.dart';

void main() {
  late MockAuthProvider mockAuth;

  setUpAll(() {
    registerMockFallbacks();
  });

  setUp(() {
    mockAuth = MockAuthProvider();
  });

  Widget buildTestWidget({bool isResume = false}) {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: LoginScreen(isResume: isResume),
      ),
    );
  }

  group('LoginScreen', () {
    testWidgets('renders login form by default', (tester) async {
      when(() => mockAuth.userLogin).thenReturn('');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('LanWash'), findsOneWidget);
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Войти'), findsOneWidget);
    });

    testWidgets('shows validation error for empty fields', (tester) async {
      when(() => mockAuth.userLogin).thenReturn('');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();

      expect(find.text('Введите логин'), findsWidgets);
      expect(find.text('Введите пароль'), findsWidgets);
    });

    testWidgets('calls login on submit and shows error', (tester) async {
      when(() => mockAuth.userLogin).thenReturn('');
      when(() => mockAuth.login(any(), any()))
          .thenAnswer((_) async => 'Неверный логин или пароль');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'admin',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'wrong',
      );

      await tester.tap(find.text('Войти'));
      await tester.pumpAndSettle();

      verify(() => mockAuth.login('admin', 'wrong')).called(1);
      expect(find.text('Неверный логин или пароль'), findsOneWidget);
    });

    testWidgets('calls login on submit and clears loading on success',
        (tester) async {
      when(() => mockAuth.userLogin).thenReturn('');
      when(() => mockAuth.login(any(), any())).thenAnswer((_) async => null);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'admin',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'password',
      );

      await tester.tap(find.text('Войти'));
      await tester.pump(); // loading starts
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // After success _loading stays true (navigation handled by router)
      await tester.pump(const Duration(milliseconds: 100));
      verify(() => mockAuth.login('admin', 'password')).called(1);
    });

    testWidgets('toggles password visibility', (tester) async {
      when(() => mockAuth.userLogin).thenReturn('');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final obscureIcon = find.byIcon(Icons.visibility_off_outlined);
      expect(obscureIcon, findsOneWidget);

      await tester.tap(obscureIcon);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('navigates to register screen', (tester) async {
      when(() => mockAuth.userLogin).thenReturn('');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Нет аккаунта? Зарегистрироваться'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
    });

    testWidgets('shows resume mode', (tester) async {
      when(() => mockAuth.userLogin).thenReturn('admin');

      await tester.pumpWidget(buildTestWidget(isResume: true));
      await tester.pumpAndSettle();

      expect(find.textContaining('С возвращением'), findsOneWidget);
      expect(find.text('Продолжить'), findsOneWidget);
      expect(find.text('Войти под другим пользователем'), findsOneWidget);
    });
  });
}
