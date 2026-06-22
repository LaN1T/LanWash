import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lanwash/core/service_locator.dart' show sl;
import 'package:lanwash/providers/auth_provider.dart';
import 'package:lanwash/providers/appointment_provider.dart';
import 'package:lanwash/providers/catalog_provider.dart';
import 'package:lanwash/providers/note_provider.dart';
import 'package:lanwash/providers/offline_provider.dart';
import 'package:lanwash/providers/theme_provider.dart';
import 'package:lanwash/providers/language_provider.dart';
import 'package:lanwash/screens/washer/washer_shell.dart';
import 'package:lanwash/services/api_service.dart';
import '../mocks.dart';

void main() {
  late MockAuthProvider mockAuth;
  late MockAppointmentProvider mockAppointment;
  late MockNoteProvider mockNote;
  late MockCatalogProvider mockCatalog;
  late MockOfflineProvider mockOffline;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    registerMockFallbacks();
    await initializeDateFormatting('ru', null);
  });

  setUp(() async {
    await sl.reset();
    sl.registerSingleton<ApiService>(MockApiService());
  });

  setUp(() {
    mockAuth = MockAuthProvider();
    mockAppointment = MockAppointmentProvider();
    mockNote = MockNoteProvider();
    mockCatalog = MockCatalogProvider();
    mockOffline = MockOfflineProvider();

    when(() => mockAuth.username).thenReturn('Washer');
    when(() => mockAuth.userLogin).thenReturn('washer');
    when(() => mockAuth.isWasher).thenReturn(true);
    when(() => mockAuth.isAdmin).thenReturn(false);
    when(() => mockAuth.isClient).thenReturn(false);
    when(() => mockAuth.user).thenReturn(null);

    when(() => mockAppointment.loading).thenReturn(false);
    when(() => mockAppointment.appointments).thenReturn([]);
    when(() => mockAppointment.reloadAppointments(any()))
        .thenAnswer((_) async {});

    when(() => mockNote.notes).thenReturn([]);
    when(() => mockNote.loadNotes(username: any(named: 'username')))
        .thenAnswer((_) async {});

    when(() => mockCatalog.washTypeById(any())).thenReturn(null);
    when(() => mockCatalog.services).thenReturn([]);

    when(() => mockOffline.isOnline).thenReturn(true);
    when(() => mockOffline.pendingCount).thenReturn(0);
  });

  Widget buildTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuth),
        ChangeNotifierProvider<AppointmentProvider>.value(
            value: mockAppointment),
        ChangeNotifierProvider<NoteProvider>.value(value: mockNote),
        ChangeNotifierProvider<CatalogProvider>.value(value: mockCatalog),
        ChangeNotifierProvider<OfflineProvider>.value(value: mockOffline),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        Provider<ApiService>(create: (_) => MockApiService()),
      ],
      child: const MaterialApp(
        home: WasherShell(),
      ),
    );
  }

  group('WasherShell', () {
    testWidgets('has two bottom nav tabs and no tips tab', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(NavigationDestination), findsNWidgets(2));
      expect(find.text('Записи'), findsOneWidget);
      expect(find.text('Заметки'), findsOneWidget);
      expect(
          find.widgetWithText(NavigationDestination, 'Чаевые'), findsNothing);
    });

    testWidgets('drawer contains new menu structure', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final scaffoldFinder = find.byWidgetPredicate(
        (w) => w is Scaffold && w.drawer != null,
        skipOffstage: false,
      );
      expect(scaffoldFinder, findsOneWidget);
      tester.state<ScaffoldState>(scaffoldFinder).openDrawer();
      await tester.pumpAndSettle();

      final drawerFinder = find.byType(Drawer);
      Finder drawerText(String text) => find.descendant(
            of: drawerFinder,
            matching: find.text(text),
          );

      expect(drawerText('Мои записи'), findsOneWidget);
      expect(drawerText('История'), findsOneWidget);
      expect(drawerText('Записаться на мойку'), findsOneWidget);
      expect(drawerText('Расписание'), findsOneWidget);
      expect(drawerText('Мой день'), findsOneWidget);
      expect(drawerText('Доступность'), findsNothing);
      expect(drawerText('Статистика'), findsNothing);

      await tester.drag(drawerFinder, const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(drawerText('Чаевые'), findsOneWidget);
      expect(drawerText('Написать в поддержку'), findsOneWidget);
      expect(drawerText('Профиль'), findsOneWidget);
      expect(drawerText('Настройки'), findsOneWidget);
      expect(drawerText('Выйти'), findsNothing);
    });
  });
}
