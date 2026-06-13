import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/models/shift.dart';
import 'package:lanwash/models/user.dart';
import 'package:lanwash/screens/shared/shift_schedule_screen.dart';

void main() {
  group('ShiftCell', () {
    final washer = User(
      id: 1,
      username: 'ivan',
      displayName: 'Иван',
      passwordHash: '',
      role: UserRole.washer,
      createdAt: DateTime(2026, 6, 15),
    );
    final shift = Shift(
      id: 1,
      userId: 1,
      date: '2026-06-15',
      startTime: '10:00',
      endTime: '18:00',
      status: 'confirmed',
      createdBy: 'admin',
      createdAt: DateTime(2026, 6, 15).toIso8601String(),
      updatedAt: DateTime(2026, 6, 15).toIso8601String(),
    );

    testWidgets('shows time and duration for confirmed shift', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShiftCell(
              washer: washer,
              date: DateTime(2026, 6, 15),
              shift: shift,
              canEdit: true,
            ),
          ),
        ),
      );
      expect(find.text('10:00–18:00'), findsOneWidget);
      expect(find.text('8 ч'), findsOneWidget);
    });

    testWidgets('shows conflict indicator for overlapping shifts',
        (tester) async {
      final overlapping = [
        shift,
        Shift(
          id: 2,
          userId: 1,
          date: '2026-06-15',
          startTime: '14:00',
          endTime: '22:00',
          status: 'confirmed',
          createdBy: 'admin',
          createdAt: DateTime(2026, 6, 15).toIso8601String(),
          updatedAt: DateTime(2026, 6, 15).toIso8601String(),
        ),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShiftCell(
              washer: washer,
              date: DateTime(2026, 6, 15),
              shift: shift,
              canEdit: true,
              dayShifts: overlapping,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });

    testWidgets('shows pending badge', (tester) async {
      final pending = Shift(
        id: 3,
        userId: 1,
        date: '2026-06-15',
        startTime: '08:00',
        endTime: '16:00',
        status: 'pending',
        createdBy: 'admin',
        createdAt: DateTime(2026, 6, 15).toIso8601String(),
        updatedAt: DateTime(2026, 6, 15).toIso8601String(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShiftCell(
              washer: washer,
              date: DateTime(2026, 6, 15),
              shift: pending,
              canEdit: true,
            ),
          ),
        ),
      );
      expect(find.text('ожид.'), findsOneWidget);
    });

    testWidgets('shows rejected label', (tester) async {
      final rejected = Shift(
        id: 4,
        userId: 1,
        date: '2026-06-15',
        startTime: '08:00',
        endTime: '16:00',
        status: 'rejected',
        createdBy: 'admin',
        createdAt: DateTime(2026, 6, 15).toIso8601String(),
        updatedAt: DateTime(2026, 6, 15).toIso8601String(),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShiftCell(
              washer: washer,
              date: DateTime(2026, 6, 15),
              shift: rejected,
              canEdit: true,
            ),
          ),
        ),
      );
      expect(find.text('Откл.'), findsOneWidget);
    });

    testWidgets('long press opens copy/delete menu', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShiftCell(
              washer: washer,
              date: DateTime(2026, 6, 15),
              shift: shift,
              canEdit: true,
              onCopy: () {},
              onClear: () {},
            ),
          ),
        ),
      );
      await tester.longPress(find.text('10:00–18:00'));
      await tester.pumpAndSettle();
      expect(find.text('Копировать'), findsOneWidget);
      expect(find.text('Удалить'), findsOneWidget);
    });
  });

  group('Shift copy/paste', () {
    testWidgets('copies and pastes a shift', (tester) async {
      final washer = User(
        id: 1,
        username: 'ivan',
        displayName: 'Иван',
        passwordHash: '',
        role: UserRole.washer,
        createdAt: DateTime(2026, 6, 15),
      );
      final shift = Shift(
        id: 1,
        userId: 1,
        date: '2026-06-15',
        startTime: '10:00',
        endTime: '18:00',
        status: 'confirmed',
        createdBy: 'admin',
        createdAt: DateTime(2026, 6, 15).toIso8601String(),
        updatedAt: DateTime(2026, 6, 15).toIso8601String(),
      );

      var copied = false;
      Shift? pastedShift;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ShiftCell(
                  washer: washer,
                  date: DateTime(2026, 6, 15),
                  shift: shift,
                  canEdit: true,
                  onCopy: () => copied = true,
                ),
                ShiftCell(
                  washer: washer,
                  date: DateTime(2026, 6, 16),
                  shift: null,
                  canEdit: true,
                  onPaste: () => pastedShift = shift,
                ),
              ],
            ),
          ),
        ),
      );

      await tester.longPress(find.text('10:00–18:00').first);
      await tester.pumpAndSettle();
      expect(find.text('Копировать'), findsOneWidget);
      await tester.tap(find.text('Копировать'));
      await tester.pumpAndSettle();
      expect(copied, true);

      await tester.longPress(find.byIcon(Icons.add).first);
      await tester.pumpAndSettle();
      expect(find.text('Вставить'), findsOneWidget);
      await tester.tap(find.text('Вставить'));
      await tester.pumpAndSettle();
      expect(pastedShift, shift);
    });
  });

  group('OnDutyAvatars', () {
    testWidgets('shows on-duty avatars', (tester) async {
      final washers = [
        User(
          id: 1,
          username: 'ivan',
          displayName: 'Иван',
          passwordHash: '',
          role: UserRole.washer,
          createdAt: DateTime(2026, 6, 15),
        ),
      ];
      final currentShifts = [
        {'userId': 1, 'shiftId': 1},
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OnDutyAvatars(
              currentShifts: currentShifts,
              washers: washers,
            ),
          ),
        ),
      );

      expect(find.text('И'), findsOneWidget);
    });

    testWidgets('is hidden when no one is on duty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OnDutyAvatars(currentShifts: [], washers: []),
          ),
        ),
      );
      expect(find.byType(CircleAvatar), findsNothing);
    });
  });

  group('BulkActionsMenu', () {
    testWidgets('admin sees bulk approve/reject actions', (tester) async {
      var approved = false;
      var rejected = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BulkActionsMenu(
              onApproveAll: () => approved = true,
              onRejectAll: () => rejected = true,
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Одобрить все заявки'), findsOneWidget);
      expect(find.text('Отклонить все заявки'), findsOneWidget);

      await tester.tap(find.text('Одобрить все заявки'));
      await tester.pumpAndSettle();
      expect(approved, true);
      expect(rejected, false);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отклонить все заявки'));
      await tester.pumpAndSettle();
      expect(rejected, true);
    });
  });
}
