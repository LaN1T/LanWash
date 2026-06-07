import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:lanwash/providers/auth_provider.dart';
import 'package:lanwash/providers/appointment_provider.dart';
import 'package:lanwash/providers/catalog_provider.dart';
import 'package:lanwash/models/appointment.dart';
import 'package:lanwash/models/service.dart';
import 'package:lanwash/models/wash_type.dart';
import 'package:lanwash/screens/admin/appointments_screen.dart';
import '../mocks.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockAppointmentProvider mockAppointment;
  late MockCatalogProvider mockCatalog;

  final testWashType = WashType(
    id: 'w1',
    code: 'basic',
    name: 'Базовая',
    description: '',
    basePrice: 800,
    durationMinutes: 30,
    sortOrder: 1,
  );

  final testService = Service(
    id: 's1',
    name: 'Чернение шин',
    description: '',
    price: 300,
    durationMinutes: 15,
    category: 'extra',
  );

  Appointment createAppointment({
    required String id,
    required String clientName,
    required String status,
    bool isFavorite = false,
  }) {
    return Appointment(
      id: id,
      clientName: clientName,
      carModel: 'Toyota',
      carNumber: 'А123БВ777',
      dateTime: DateTime(2026, 5, 30, 15, 0),
      washTypeId: 'w1',
      additionalServices: ['s1'],
      status: status,
      isFavorite: isFavorite,
    );
  }

  setUpAll(() async {
    await initializeDateFormatting('ru');
    registerMockFallbacks();
  });

  setUp(() {
    mockAuth = MockAuthProvider();
    mockAppointment = MockAppointmentProvider();
    mockCatalog = MockCatalogProvider();
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
          ChangeNotifierProvider<AppointmentProvider>.value(value: mockAppointment),
          ChangeNotifierProvider<CatalogProvider>.value(value: mockCatalog),
        ],
        child: const Scaffold(
          body: AppointmentsScreen(),
        ),
      ),
    );
  }

  group('AppointmentsScreen', () {
    testWidgets('shows loading indicator', (tester) async {
      when(() => mockAppointment.loading).thenReturn(true);

      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no appointments', (tester) async {
      when(() => mockAppointment.loading).thenReturn(false);
      when(() => mockAppointment.appointments).thenReturn([]);
      when(() => mockCatalog.services).thenReturn([]);
      when(() => mockAppointment.totalPages).thenReturn(1);
      when(() => mockAppointment.currentPage).thenReturn(1);
      when(() => mockAppointment.currentDate).thenReturn('2026-05-30');
      when(() => mockAppointment.uniqueDates).thenReturn(['2026-05-30']);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Нет записей'), findsOneWidget);
      expect(find.text('Нажмите + чтобы добавить запись'), findsOneWidget);
    });

    testWidgets('shows list of appointments', (tester) async {
      final appointments = [
        createAppointment(id: 'a1', clientName: 'Иван', status: 'scheduled'),
        createAppointment(id: 'a2', clientName: 'Мария', status: 'completed'),
      ];

      when(() => mockAppointment.loading).thenReturn(false);
      when(() => mockAppointment.appointments).thenReturn(appointments);
      when(() => mockCatalog.services).thenReturn([testService]);
      when(() => mockCatalog.washTypeById(any())).thenReturn(testWashType);
      when(() => mockCatalog.washTypeName(any())).thenReturn('Базовая');
      when(() => mockAppointment.totalPages).thenReturn(1);
      when(() => mockAppointment.currentPage).thenReturn(1);
      when(() => mockAppointment.currentDate).thenReturn('2026-05-30');
      when(() => mockAppointment.uniqueDates).thenReturn(['2026-05-30']);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Иван'), findsOneWidget);
      expect(find.text('Мария'), findsOneWidget);
      expect(find.text('Toyota'), findsWidgets);
    });

    testWidgets('filters appointments by status', (tester) async {
      final appointments = [
        createAppointment(id: 'a1', clientName: 'Иван', status: 'scheduled'),
        createAppointment(id: 'a2', clientName: 'Мария', status: 'completed'),
      ];

      when(() => mockAppointment.loading).thenReturn(false);
      when(() => mockAppointment.appointments).thenReturn(appointments);
      when(() => mockCatalog.services).thenReturn([testService]);
      when(() => mockCatalog.washTypeById(any())).thenReturn(testWashType);
      when(() => mockCatalog.washTypeName(any())).thenReturn('Базовая');
      when(() => mockAppointment.totalPages).thenReturn(1);
      when(() => mockAppointment.currentPage).thenReturn(1);
      when(() => mockAppointment.currentDate).thenReturn('2026-05-30');
      when(() => mockAppointment.uniqueDates).thenReturn(['2026-05-30']);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initial: both visible
      expect(find.text('Иван'), findsOneWidget);
      expect(find.text('Мария'), findsOneWidget);

      // Tap "Завершены" filter
      await tester.tap(find.text('Завершены'));
      await tester.pumpAndSettle();

      expect(find.text('Иван'), findsNothing);
      expect(find.text('Мария'), findsOneWidget);

      // Tap "Все" to reset
      await tester.tap(find.text('Все'));
      await tester.pumpAndSettle();

      expect(find.text('Иван'), findsOneWidget);
      expect(find.text('Мария'), findsOneWidget);
    });

    testWidgets('searches appointments by client name', (tester) async {
      final appointments = [
        createAppointment(id: 'a1', clientName: 'Иван Петров', status: 'scheduled'),
        createAppointment(id: 'a2', clientName: 'Мария Сидорова', status: 'scheduled'),
      ];

      when(() => mockAppointment.loading).thenReturn(false);
      when(() => mockAppointment.appointments).thenReturn(appointments);
      when(() => mockCatalog.services).thenReturn([testService]);
      when(() => mockCatalog.washTypeById(any())).thenReturn(testWashType);
      when(() => mockCatalog.washTypeName(any())).thenReturn('Базовая');
      when(() => mockAppointment.totalPages).thenReturn(1);
      when(() => mockAppointment.currentPage).thenReturn(1);
      when(() => mockAppointment.currentDate).thenReturn('2026-05-30');
      when(() => mockAppointment.uniqueDates).thenReturn(['2026-05-30']);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextField).first,
        'иван',
      );
      await tester.pumpAndSettle();

      expect(find.text('Иван Петров'), findsOneWidget);
      expect(find.text('Мария Сидорова'), findsNothing);
    });

    testWidgets('shows pagination when multiple pages', (tester) async {
      when(() => mockAppointment.loading).thenReturn(false);
      when(() => mockAppointment.appointments).thenReturn([]);
      when(() => mockCatalog.services).thenReturn([]);
      when(() => mockAppointment.totalPages).thenReturn(3);
      when(() => mockAppointment.currentPage).thenReturn(2);
      when(() => mockAppointment.currentDate).thenReturn('2026-05-30');
      when(() => mockAppointment.uniqueDates).thenReturn([
        '2026-05-30',
        '2026-05-29',
        '2026-05-28',
      ]);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
      expect(find.textContaining('Сегодня'), findsOneWidget);
    });

    testWidgets('hides pagination when single page', (tester) async {
      when(() => mockAppointment.loading).thenReturn(false);
      when(() => mockAppointment.appointments).thenReturn([]);
      when(() => mockCatalog.services).thenReturn([]);
      when(() => mockAppointment.totalPages).thenReturn(1);
      when(() => mockAppointment.currentPage).thenReturn(1);
      when(() => mockAppointment.currentDate).thenReturn('2026-05-30');
      when(() => mockAppointment.uniqueDates).thenReturn(['2026-05-30']);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
    });

    testWidgets('triggers refresh on pull', (tester) async {
      final appointments = [
        createAppointment(id: 'a1', clientName: 'Иван', status: 'scheduled'),
      ];

      when(() => mockAppointment.loading).thenReturn(false);
      when(() => mockAppointment.appointments).thenReturn(appointments);
      when(() => mockCatalog.services).thenReturn([testService]);
      when(() => mockCatalog.washTypeById(any())).thenReturn(testWashType);
      when(() => mockCatalog.washTypeName(any())).thenReturn('Базовая');
      when(() => mockAppointment.totalPages).thenReturn(1);
      when(() => mockAppointment.currentPage).thenReturn(1);
      when(() => mockAppointment.currentDate).thenReturn('2026-05-30');
      when(() => mockAppointment.uniqueDates).thenReturn(['2026-05-30']);
      when(() => mockAppointment.reloadAppointments(any()))
          .thenAnswer((_) => Future.value());

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      await tester.fling(
        find.descendant(
          of: find.byType(RefreshIndicator),
          matching: find.byType(ListView),
        ),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      verify(() => mockAppointment.reloadAppointments(mockAuth)).called(1);
    });
  });
}
