import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lanwash/models/user.dart';
import 'package:lanwash/models/washer_availability.dart';
import 'package:lanwash/widgets/shift_schedule/washer_availability_grid.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('ru_RU');
  });

  final washer = User(
    id: 1,
    username: 'washer_test',
    displayName: 'Washer Test',
    role: UserRole.washer,
    passwordHash: '',
    createdAt: DateTime(2026),
  );

  testWidgets('tapping a cell cycles statuses and save calls onSave',
      (tester) async {
    List<WasherAvailability>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WasherAvailabilityGrid(
            washer: washer,
            weekStart: DateTime(2026, 6, 8),
            availability: const [],
            onSave: (entries) => saved = entries,
          ),
        ),
      ),
    );

    final firstCell = find.byType(GestureDetector).first;
    expect(firstCell, findsOneWidget);

    // First tap -> available
    await tester.tap(firstCell);
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // Second tap -> unavailable
    await tester.tap(firstCell);
    await tester.pump();
    expect(find.byIcon(Icons.cancel), findsOneWidget);

    // Third tap -> unknown
    await tester.tap(firstCell);
    await tester.pump();
    expect(find.byIcon(Icons.help_outline), findsWidgets);

    // Fourth tap -> available again
    await tester.tap(firstCell);
    await tester.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    // Fifth tap -> unavailable, then save
    await tester.tap(firstCell);
    await tester.pump();
    expect(find.byIcon(Icons.cancel), findsOneWidget);
    await tester.tap(find.text('Сохранить'));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.length, 1);
    expect(saved!.first.status, 'unavailable');
  });

  testWidgets('mark all available button sets every day to available',
      (tester) async {
    List<WasherAvailability>? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WasherAvailabilityGrid(
            washer: washer,
            weekStart: DateTime(2026, 6, 8),
            availability: const [],
            onSave: (entries) => saved = entries,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Вся неделя доступна'));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsNWidgets(7));

    await tester.tap(find.text('Сохранить'));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.length, 7);
    expect(saved!.every((e) => e.status == 'available'), isTrue);
  });
}
