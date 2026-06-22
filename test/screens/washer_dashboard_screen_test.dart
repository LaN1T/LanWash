import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanwash/models/appointment.dart';
import 'package:lanwash/providers/appointment_provider.dart';
import 'package:lanwash/providers/auth_provider.dart';
import 'package:lanwash/providers/catalog_provider.dart';
import 'package:lanwash/providers/language_provider.dart';
import 'package:lanwash/providers/theme_provider.dart';
import 'package:lanwash/screens/washer/washer_dashboard_screen.dart';
import 'package:lanwash/services/api_service.dart';

import '../mocks.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockAppointmentProvider mockAppointment;
  late MockCatalogProvider mockCatalog;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    registerMockFallbacks();
    await initializeDateFormatting('ru', null);
  });

  setUp(() {
    mockAuth = MockAuthProvider();
    mockAppointment = MockAppointmentProvider();
    mockCatalog = MockCatalogProvider();

    when(() => mockAuth.username).thenReturn('Иван');
    when(() => mockAuth.userLogin).thenReturn('washer1');
    when(() => mockAuth.isWasher).thenReturn(true);

    when(() => mockAppointment.loading).thenReturn(false);
    when(() => mockAppointment.appointments).thenReturn([]);
    when(() => mockAppointment.reloadAppointments(any()))
        .thenAnswer((_) async {});

    when(() => mockCatalog.washTypeById(any())).thenReturn(null);
    when(() => mockCatalog.services).thenReturn([]);
    when(() => mockCatalog.washTypeName(any())).thenReturn('Мойка');
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<AppointmentProvider>.value(
            value: mockAppointment),
        ChangeNotifierProvider<CatalogProvider>.value(value: mockCatalog),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        Provider<ApiService>(create: (_) => MockApiService()),
      ],
      child: const MaterialApp(
        home: WasherDashboardScreen(),
      ),
    );
  }

  testWidgets('shows greeting and empty state', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.textContaining('Иван'), findsOneWidget);
    expect(find.text('На сегодня назначений нет'), findsOneWidget);
  });

  testWidgets('shows today count and next appointment', (tester) async {
    final now = DateTime.now();
    when(() => mockAppointment.appointments).thenReturn([
      Appointment(
        id: '1',
        clientName: 'Алексей',
        carModel: 'Kia',
        carNumber: 'A123',
        dateTime: now.add(const Duration(hours: 2)),
        washTypeId: 'basic',
        additionalServices: const [],
        status: 'scheduled',
        assignedWashers: const ['washer1'],
      ),
      Appointment(
        id: '2',
        clientName: 'Мария',
        carModel: 'BMW',
        carNumber: 'B456',
        dateTime: now.add(const Duration(hours: 4)),
        washTypeId: 'basic',
        additionalServices: const [],
        status: 'scheduled',
        assignedWashers: const ['washer1'],
      ),
    ]);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('ближайшая'), findsOneWidget);
    expect(find.text('Алексей'), findsOneWidget);
    expect(find.text('Мария'), findsOneWidget);
  });
}
