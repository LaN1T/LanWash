import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/models/shift_load_report.dart';
import 'package:lanwash/widgets/shift_schedule/shift_analytics_view.dart';

void main() {
  const report = ShiftLoadReport(
    startDate: '2026-06-08',
    endDate: '2026-06-14',
    targetWeeklyMinutesPerWasher: 2400,
    dailyHours: [
      ShiftLoadDailyEntry(date: '2026-06-08', confirmedMinutes: 240, pendingMinutes: 60),
      ShiftLoadDailyEntry(date: '2026-06-09', confirmedMinutes: 480, pendingMinutes: 0),
    ],
    washerStats: [
      ShiftLoadWasherStat(
        userId: 1,
        displayName: 'Иван',
        confirmedMinutes: 720,
        pendingMinutes: 60,
        rejectedMinutes: 0,
        utilizationPercent: 30.0,
        isOvertime: false,
        isUnderload: true,
      ),
      ShiftLoadWasherStat(
        userId: 2,
        displayName: 'Петр',
        confirmedMinutes: 3000,
        pendingMinutes: 0,
        rejectedMinutes: 0,
        utilizationPercent: 125.0,
        isOvertime: true,
        isUnderload: false,
      ),
    ],
    statusCounts: ShiftLoadStatusCounts(confirmed: 2, pending: 1, rejected: 0),
    conflictCount: 0,
    availabilityCoverage: ShiftLoadAvailabilityCoverage(
      availableDays: 10,
      unavailableDays: 2,
      unknownDays: 2,
    ),
  );

  testWidgets('renders KPI row, chart, washer stats and availability chips', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftAnalyticsView(
            report: report,
            weekStart: DateTime(2026, 6, 8),
          ),
        ),
      ),
    );

    expect(find.text('Всего часов'), findsOneWidget);
    expect(find.text('На рассмотрении'), findsOneWidget);
    expect(find.text('Конфликтов'), findsOneWidget);
    expect(find.text('Перегрузок'), findsOneWidget);
    expect(find.text('Часы по дням недели'), findsOneWidget);
    expect(find.text('Загрузка по мойщикам'), findsOneWidget);
    expect(find.text('Доступность мойщиков'), findsOneWidget);
    expect(find.text('Иван'), findsOneWidget);
    expect(find.text('Петр'), findsOneWidget);
    expect(find.text('Доступны: 10'), findsOneWidget);
    expect(find.text('Недоступны: 2'), findsOneWidget);
    expect(find.text('Не указано: 2'), findsOneWidget);
  });
}
