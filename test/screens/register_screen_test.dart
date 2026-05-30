import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:lanwash/providers/auth_provider.dart';
import 'package:lanwash/providers/app_provider.dart';
import 'package:lanwash/screens/auth/register_screen.dart';
import '../mocks.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockAppProvider mockApp;

  setUpAll(() {
    registerMockFallbacks();
  });

  setUp(() {
    mockAuth = MockAuthProvider();
    mockApp = MockAppProvider();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<AppProvider>.value(value: mockApp),
        ],
        child: const RegisterScreen(),
      ),
    );
  }

  group('RegisterScreen', () {
    testWidgets('renders registration form', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Создать аккаунт'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.text('Зарегистрироваться'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty fields', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();

      expect(find.text('Введите имя'), findsOneWidget);
      expect(find.text('Введите логин'), findsOneWidget);
      expect(find.text('Введите пароль'), findsOneWidget);
      expect(find.text('Введите телефон'), findsOneWidget);
    });

    testWidgets('shows validation error for short login', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(1), 'ab');
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();

      expect(find.text('Минимум 3 символа'), findsOneWidget);
    });

    testWidgets('shows validation error for short password', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(2), '123');
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();

      expect(find.text('Минимум 4 символа'), findsOneWidget);
    });

    testWidgets('calls register and shows error', (tester) async {
      when(() => mockAuth.register(
            username: any(named: 'username'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => 'Логин уже занят');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Иван');
      await tester.enterText(find.byType(TextFormField).at(1), 'ivan123');
      await tester.enterText(find.byType(TextFormField).at(2), 'password');
      await tester.enterText(find.byType(TextFormField).at(3), '+7 (999) 000-00-00');

      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();

      verify(() => mockAuth.register(
            username: 'ivan123',
            password: 'password',
            displayName: 'Иван',
            phone: '+7 (999) 000-00-00',
          )).called(1);
      expect(find.text('Логин уже занят'), findsOneWidget);
    });

    testWidgets('successful registration reloads data and pops', (tester) async {
      when(() => mockAuth.register(
            username: any(named: 'username'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) async => null);
      when(() => mockAuth.userLogin).thenReturn('ivan123');
      when(() => mockApp.reloadForUser(any(), any()))
          .thenAnswer((_) => Future.value());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Иван');
      await tester.enterText(find.byType(TextFormField).at(1), 'ivan123');
      await tester.enterText(find.byType(TextFormField).at(2), 'password');
      await tester.enterText(find.byType(TextFormField).at(3), '+7 (999) 000-00-00');

      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pump(); // loading starts
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 100));

      verify(() => mockApp.reloadForUser('ivan123', mockAuth)).called(1);
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final obscureIcon = find.byIcon(Icons.visibility_off_outlined);
      expect(obscureIcon, findsOneWidget);

      await tester.tap(obscureIcon);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('phone formatter adds +7 prefix', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final phoneField = find.byType(TextFormField).at(3);
      await tester.enterText(phoneField, '9990000000');
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(phoneField);
      expect(field.controller?.text, '+7 (999) 000-00-00');
    });
  });
}
