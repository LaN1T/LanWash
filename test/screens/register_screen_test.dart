import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanwash/providers/auth_provider.dart';
import 'package:lanwash/providers/appointment_provider.dart';
import 'package:lanwash/providers/theme_provider.dart';
import 'package:lanwash/providers/language_provider.dart';
import 'package:lanwash/screens/auth/register_screen.dart';
import '../mocks.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockAppointmentProvider mockAppointment;

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerMockFallbacks();
  });

  setUp(() {
    mockAuth = MockAuthProvider();
    mockAppointment = MockAppointmentProvider();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<AppointmentProvider>.value(
              value: mockAppointment),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ],
        child: const RegisterScreen(),
      ),
    );
  }

  group('RegisterScreen', () {
    testWidgets('renders registration form', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Регистрация'), findsNWidgets(2));
      expect(find.byType(TextFormField), findsNWidgets(6));
      expect(find.text('Зарегистрироваться'), findsOneWidget);
    });

    testWidgets('shows validation errors for empty fields', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Зарегистрироваться'));
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();

      expect(find.text('Обязательное поле'), findsNWidgets(3));
      expect(find.text('Введите пароль'), findsOneWidget);
    });

    testWidgets('shows validation error for short login', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(2), 'ab');
      await tester.ensureVisible(find.text('Зарегистрироваться'));
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();

      expect(find.text('Минимум 3 символа'), findsOneWidget);
    });

    testWidgets('shows validation error for short password', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(3), '123');
      await tester.ensureVisible(find.text('Зарегистрироваться'));
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();

      expect(find.text('Минимум 8 символов'), findsOneWidget);
    });

    testWidgets('calls register and shows error', (tester) async {
      when(() => mockAuth.register(
                username: any(named: 'username'),
                password: any(named: 'password'),
                displayName: any(named: 'displayName'),
                email: any(named: 'email'),
                phone: any(named: 'phone'),
              ))
          .thenAnswer((_) async =>
              'Регистрация не удалась. Проверьте введённые данные.');

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Иван');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'ivan123');
      await tester.enterText(find.byType(TextFormField).at(3), 'TestPass123!');
      await tester.enterText(
          find.byType(TextFormField).at(5), '+7 (999) 000-00-00');

      await tester.ensureVisible(find.text('Зарегистрироваться'));
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pumpAndSettle();

      verify(() => mockAuth.register(
            username: 'ivan123',
            password: 'TestPass123!',
            displayName: 'Иван',
            email: 'test@example.com',
            phone: '+7 (999) 000-00-00',
          )).called(1);
      expect(find.text('Регистрация не удалась. Проверьте введённые данные.'),
          findsOneWidget);
    });

    testWidgets('successful registration reloads data and pops',
        (tester) async {
      when(() => mockAuth.register(
            username: any(named: 'username'),
            password: any(named: 'password'),
            displayName: any(named: 'displayName'),
            email: any(named: 'email'),
            phone: any(named: 'phone'),
          )).thenAnswer((_) => Future.delayed(
              const Duration(milliseconds: 100), () => null));
      when(() => mockAuth.userLogin).thenReturn('ivan123');
      when(() => mockAppointment.reloadForUser(any(), any()))
          .thenAnswer((_) => Future.value());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Иван');
      await tester.enterText(
          find.byType(TextFormField).at(1), 'test@example.com');
      await tester.enterText(find.byType(TextFormField).at(2), 'ivan123');
      await tester.enterText(find.byType(TextFormField).at(3), 'TestPass123!');
      await tester.enterText(
          find.byType(TextFormField).at(5), '+7 (999) 000-00-00');

      await tester.ensureVisible(find.text('Зарегистрироваться'));
      await tester.tap(find.text('Зарегистрироваться'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 150));

      verify(() => mockAppointment.reloadForUser('ivan123', mockAuth))
          .called(1);
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

      final phoneField = find.byType(TextFormField).at(5);
      await tester.enterText(phoneField, '9990000000');
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(phoneField);
      expect(field.controller?.text, '+7 (999) 000-00-00');
    });
  });
}
