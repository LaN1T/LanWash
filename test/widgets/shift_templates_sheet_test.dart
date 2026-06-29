import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lanwash/models/shift_template.dart';
import 'package:lanwash/widgets/shift_schedule/shift_templates_sheet.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('ru_RU');
  });
  testWidgets('ShiftTemplatesSheet renders templates and apply button',
      (tester) async {
    final templates = [
      const ShiftTemplate(
        id: 1,
        ownerUsername: 'admin',
        name: 'Будни',
        isDefault: true,
        slots: [
          ShiftTemplateSlot(weekday: 1, startTime: '09:00', endTime: '18:00'),
        ],
      ),
    ];

    var applied = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftTemplatesSheet(
            templates: templates,
            weekStart: DateTime(2026, 6, 8),
            onRefresh: () {},
            onSave: (_, __) async {},
            onApply: (_) async => applied = true,
            onDelete: (_) async {},
            onSetDefault: (_, __) async {},
          ),
        ),
      ),
    );

    expect(find.text('Будни'), findsOneWidget);
    expect(find.byIcon(Icons.star), findsOneWidget);
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(applied, isTrue);
  });

  testWidgets('ShiftTemplatesSheet shows empty state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShiftTemplatesSheet(
            templates: const [],
            weekStart: DateTime(2026, 6, 8),
            onRefresh: () {},
            onSave: (_, __) async {},
            onApply: (_) async {},
            onDelete: (_) async {},
            onSetDefault: (_, __) async {},
          ),
        ),
      ),
    );

    expect(find.text('Нет сохранённых шаблонов'), findsOneWidget);
  });
}
