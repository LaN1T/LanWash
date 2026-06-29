import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:lanwash/models/financial_report.dart';
import 'package:lanwash/screens/admin/reports_shell_screen.dart';
import 'package:lanwash/services/api_service.dart';

import '../mocks.dart';

void main() {
  final sl = GetIt.instance;

  setUp(() async {
    await initializeDateFormatting('ru', null);
    await sl.reset();
    sl.registerSingleton<ApiService>(MockApiService());
    when(() => sl<ApiService>().getFinancialReport(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          groupBy: any(named: 'groupBy'),
          washerUsername: any(named: 'washerUsername'),
          washTypeId: any(named: 'washTypeId'),
          promoId: any(named: 'promoId'),
        )).thenAnswer((_) async => FinancialReport(
          summary: {'revenue': 0, 'appointments_count': 0},
          items: [],
        ));
    when(() => sl<ApiService>().getWashers()).thenAnswer((_) async => []);
    when(() => sl<ApiService>().getWashTypes()).thenAnswer((_) async => []);
    when(() => sl<ApiService>().getPromos()).thenAnswer((_) async => []);
  });

  tearDown(() async {
    await sl.reset();
  });

  Widget buildTestWidget({required Widget child}) {
    return MaterialApp(home: child);
  }

  testWidgets('ReportsShell shows report groups and navigates', (tester) async {
    await tester.pumpWidget(buildTestWidget(child: const ReportsShellScreen()));
    await tester.pumpAndSettle();

    expect(find.text('ФИНАНСЫ И ПРОДАЖИ'), findsOneWidget);
    expect(find.text('КАЧЕСТВО И РЕСУРСЫ'), findsOneWidget);
    expect(find.text('Финансовый отчёт'), findsOneWidget);
    expect(find.text('Зарплата мойщиков'), findsOneWidget);
    expect(find.text('Эффективность акций'), findsOneWidget);
    expect(find.text('Отмены и возвраты'), findsOneWidget);
    expect(find.text('Средний чек по моделям'), findsOneWidget);
    expect(find.text('Популярные услуги'), findsOneWidget);
    expect(find.text('Расходники'), findsOneWidget);

    await tester.tap(find.text('Финансовый отчёт'));
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsOneWidget);
  });
}
