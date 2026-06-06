import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/widgets/car_autocomplete_field.dart';

void main() {
  testWidgets('CarAutocompleteField renders and suggests', (tester) async {
    final ctrl = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarAutocompleteField(
            label: 'Brand',
            icon: Icons.directions_car,
            controller: ctrl,
            optionsBuilder: (q) => ['Toyota', 'Tesla']
                .where((b) => b.toLowerCase().startsWith(q.toLowerCase()))
                .toList(),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'To');
    await tester.pump();

    expect(find.text('Toyota'), findsOneWidget);
    expect(find.text('Tesla'), findsOneWidget);

    await tester.tap(find.text('Toyota'));
    await tester.pump();

    expect(ctrl.text, 'Toyota');
  });

  testWidgets('CarAutocompleteField respects enabled=false', (tester) async {
    final ctrl = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarAutocompleteField(
            label: 'Brand',
            icon: Icons.directions_car,
            controller: ctrl,
            enabled: false,
            optionsBuilder: (q) => [],
          ),
        ),
      ),
    );

    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.enabled, false);
  });
}
