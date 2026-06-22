# Washer workspace redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the washer's main bottom tab into a work bookings list, merge schedule/availability in the drawer, and add a "Мой день" dashboard.

**Architecture:** Reuse the existing client bookings pattern (`MyBookingsScreen`) for the washer work list, filtering by `assignedWashers` instead of owner. Add a small dashboard screen that reads from the same `AppointmentProvider`. Keep `ShiftScheduleScreen` as the single schedule entry point; availability is its second tab.

**Tech Stack:** Flutter, Provider, mocktail for tests.

---

## File map

- **Create** `lib/screens/washer/washer_appointments_screen.dart` — work bookings list (active/history tabs).
- **Create** `lib/screens/washer/washer_dashboard_screen.dart` — "Мой день" dashboard.
- **Modify** `lib/screens/washer/washer_shell.dart` — swap tab body, update drawer menu, remove dead `_WasherAppointmentsTab`.
- **Modify** `test/screens/washer_shell_test.dart` — update drawer expectations.
- **Create** `test/screens/washer_dashboard_screen_test.dart` — basic dashboard tests.

---

## Task 1: Create washer work bookings screen

**Files:**
- Create: `lib/screens/washer/washer_appointments_screen.dart`
- Test: `test/screens/washer_appointments_screen_test.dart` (optional, or cover in shell test)

The screen is analogous to `lib/screens/client/my_bookings_screen.dart` but:
- filters by `assignedWashers.contains(auth.userLogin)` (case-insensitive);
- uses `WasherAppointmentCard`;
- tabs are "Активные" / "История".

- [ ] **Step 1: Create `WasherAppointmentsScreen`**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/washer/washer_appointment_card.dart';

class WasherAppointmentsScreen extends StatefulWidget {
  const WasherAppointmentsScreen({super.key});

  @override
  State<WasherAppointmentsScreen> createState() => _State();
}

class _State extends State<WasherAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<Appointment> _filtered(AppointmentProvider provider, AuthProvider auth) {
    final login = auth.userLogin.toLowerCase();
    return provider.appointments.where((a) {
      return a.assignedWashers
          .any((w) => w.toLowerCase() == login);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final auth = context.watch<AuthProvider>();

    final all = _filtered(appointmentProvider, auth)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final upcoming = all
        .where((a) => a.status == 'scheduled' || a.status == 'in_progress')
        .toList();
    final history = all
        .where((a) => a.status == 'completed' || a.status == 'cancelled')
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Column(
      children: [
        Container(
          color: AppStyles.adaptiveCard(context),
          child: TabBar(
            controller: _tab,
            labelColor: AppStyles.primary,
            unselectedLabelColor: AppStyles.adaptiveTextSecondary(context),
            indicatorColor: AppStyles.primary,
            tabs: const [Tab(text: 'Активные'), Tab(text: 'История')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _AppointmentsList(items: upcoming),
              _AppointmentsList(items: history),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppointmentsList extends StatelessWidget {
  final List<Appointment> items;
  const _AppointmentsList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_outlined,
                size: 64,
                color: AppStyles.adaptiveTextSecondary(context)
                    .withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('Нет записей',
                style: AppStyles.headingMedium.copyWith(
                    color: AppStyles.adaptiveTextSecondary(context))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppStyles.primary,
      onRefresh: () => context
          .read<AppointmentProvider>()
          .reloadAppointments(context.read<AuthProvider>()),
      child: ListView.builder(
        padding: AppStyles.pagePadding,
        itemCount: items.length,
        itemBuilder: (_, i) => WasherAppointmentCard(appointment: items[i]),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/screens/washer/washer_appointments_screen.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/washer/washer_appointments_screen.dart
git commit -m "feat(washer): add work appointments list screen"
```

---

## Task 2: Create "Мой день" dashboard screen

**Files:**
- Create: `lib/screens/washer/washer_dashboard_screen.dart`
- Test: `test/screens/washer_dashboard_screen_test.dart`

- [ ] **Step 1: Create `WasherDashboardScreen`**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../widgets/washer/washer_appointment_card.dart';
import '../shared/shift_schedule_screen.dart';
import '../shared/statistics_screen.dart';

class WasherDashboardScreen extends StatelessWidget {
  const WasherDashboardScreen({super.key});

  List<Appointment> _todayAppointments(
      AppointmentProvider provider, AuthProvider auth) {
    final login = auth.userLogin.toLowerCase();
    final now = DateTime.now();
    return provider.appointments.where((a) {
      final assigned = a.assignedWashers
          .any((w) => w.toLowerCase() == login);
      final sameDay = a.dateTime.year == now.year &&
          a.dateTime.month == now.month &&
          a.dateTime.day == now.day;
      return assigned && sameDay;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appointmentProvider = context.watch<AppointmentProvider>();
    final today = _todayAppointments(appointmentProvider, auth);
    final next = today.isNotEmpty ? today.first : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppStyles.primary,
        onRefresh: () => appointmentProvider.reloadAppointments(auth),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Добрый день, ${auth.username}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppStyles.cardDecorationFor(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Сегодня',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.primary)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${today.length}',
                                  style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'запис${today.length == 1 ? 'ь' : (today.length < 5 ? 'и' : 'ей')}',
                                  style: TextStyle(
                                      color: AppStyles.adaptiveTextSecondary(
                                          context)),
                                ),
                              ],
                            ),
                          ),
                          if (next != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('HH:mm', 'ru')
                                        .format(next.dateTime),
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'ближайшая',
                                    style: TextStyle(
                                        color: AppStyles.adaptiveTextSecondary(
                                            context)),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ShiftScheduleScreen()),
                              ),
                              icon: const Icon(Icons.schedule, size: 18),
                              label: const Text('Расписание'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const StatisticsScreen()),
                              ),
                              icon: const Icon(Icons.bar_chart, size: 18),
                              label: const Text('Статистика'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              sliver: today.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          'На сегодня назначений нет',
                          style: TextStyle(
                              color: AppStyles.adaptiveTextSecondary(context)),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => WasherAppointmentCard(
                            appointment: today[index]),
                        childCount: today.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/screens/washer/washer_dashboard_screen.dart`
Expected: no errors.

- [ ] **Step 3: Commit**

```bash
git add lib/screens/washer/washer_dashboard_screen.dart
git commit -m "feat(washer): add my day dashboard screen"
```

---

## Task 3: Wire screens into `WasherShell`

**Files:**
- Modify: `lib/screens/washer/washer_shell.dart`

- [ ] **Step 1: Replace tab body**

In `WasherShell` `IndexedStack`, change tab 0 body from `_WasherAppointmentsTab()` to `WasherAppointmentsScreen()` and add the import:

```dart
import 'washer_appointments_screen.dart';
import 'washer_dashboard_screen.dart';
```

- [ ] **Step 2: Update drawer "Работа" section**

Replace the existing "Расписание" + "Доступность" + "Статистика" tiles with:

```dart
section('Работа'),
tile(
  icon: Icons.schedule_outlined,
  title: 'Расписание',
  onTap: () {
    Navigator.pop(ctx);
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => const ShiftScheduleScreen()),
    );
  },
),
tile(
  icon: Icons.work_outline_rounded,
  title: 'Мой день',
  onTap: () {
    Navigator.pop(ctx);
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => const WasherDashboardScreen()),
    );
  },
),
tile(
  icon: Icons.volunteer_activism_outlined,
  title: 'Чаевые',
  ...
),
```

Remove the "Доступность" and "Статистика" tiles from the drawer.

- [ ] **Step 3: Remove dead `_WasherAppointmentsTab` class**

Delete the `_WasherAppointmentsTab` and `_WasherAppointmentsTabState` classes from `washer_shell.dart` (lines ~353-544). They are no longer used.

- [ ] **Step 4: Run existing washer tests**

Run: `flutter test test/screens/washer_shell_test.dart`
Expected: tests fail because drawer expectations changed.

- [ ] **Step 5: Commit**

```bash
git add lib/screens/washer/washer_shell.dart
git commit -m "feat(washer): wire new work list and dashboard into shell"
```

---

## Task 4: Update washer shell tests

**Files:**
- Modify: `test/screens/washer_shell_test.dart`

- [ ] **Step 1: Update drawer expectations**

Replace the assertions in `drawer contains new menu structure`:

```dart
expect(drawerText('Мои записи'), findsOneWidget);
expect(drawerText('История'), findsOneWidget);
expect(drawerText('Записаться на мойку'), findsOneWidget);
expect(drawerText('Расписание'), findsOneWidget);
expect(drawerText('Мой день'), findsOneWidget);
expect(drawerText('Доступность'), findsNothing);
expect(drawerText('Статистика'), findsNothing);
```

- [ ] **Step 2: Add mock for `assignedWashers`** (if needed)

The new screen reads `appointmentProvider.appointments`. In the existing mock `appointments` is empty, so the empty-state path is covered automatically.

- [ ] **Step 3: Run tests**

Run: `flutter test test/screens/washer_shell_test.dart`
Expected: all pass.

- [ ] **Step 4: Commit**

```bash
git add test/screens/washer_shell_test.dart
git commit -m "test(washer): update shell drawer expectations"
```

---

## Task 5: Add dashboard tests

**Files:**
- Create: `test/screens/washer_dashboard_screen_test.dart`

- [ ] **Step 1: Write tests**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    registerMockFallbacks();
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
```

- [ ] **Step 2: Run tests**

Run: `flutter test test/screens/washer_dashboard_screen_test.dart`
Expected: all pass.

- [ ] **Step 3: Commit**

```bash
git add test/screens/washer_dashboard_screen_test.dart
git commit -m "test(washer): add dashboard screen tests"
```

---

## Task 6: Final verification

- [ ] **Step 1: Run all washer-related tests**

Run: `flutter test test/screens/washer_shell_test.dart test/screens/washer_dashboard_screen_test.dart test/providers/appointment_provider_ws_test.dart`
Expected: all pass.

- [ ] **Step 2: Format**

Run: `dart format --output=none --set-exit-if-changed lib/ test/`
Expected: no changes needed.

- [ ] **Step 3: Push**

```bash
git push origin main
```

---

## Spec coverage check

- Bottom tab becomes work bookings list → Task 1 + Task 3.
- Drawer merges schedule/availability → Task 3.
- New "Мой день" dashboard → Task 2 + Task 5.
- Statistics moved out of drawer → Task 3.
- Tests updated/added → Task 4 + Task 5.

No placeholders. All tasks produce testable changes.
