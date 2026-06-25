import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/widgets/admin/admin_card.dart';
import 'package:lanwash/screens/admin/reports/financial_report_screen.dart';
import 'package:lanwash/screens/admin/reports/washer_payroll_report_screen.dart';
import 'package:lanwash/screens/admin/reports/cancellations_report_screen.dart';
import 'package:lanwash/screens/admin/reports/promo_effectiveness_report_screen.dart';
import 'package:lanwash/screens/admin/reports/average_check_report_screen.dart';
import 'package:lanwash/screens/admin/reports/popular_services_report_screen.dart';
import 'package:lanwash/screens/admin/reports/consumables_report_screen.dart';

class ReportsShellScreen extends StatelessWidget {
  const ReportsShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reports = [
      _ReportItem(
        title: 'Финансовый отчёт',
        subtitle: 'Выручка по дням, неделям, месяцам',
        group: 'ФИНАНСЫ И ПРОДАЖИ',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const FinancialReportScreen())),
      ),
      _ReportItem(
        title: 'Зарплата мойщиков',
        subtitle: 'Записи, услуги, чаевые, итого',
        group: 'ФИНАНСЫ И ПРОДАЖИ',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const WasherPayrollReportScreen())),
      ),
      _ReportItem(
        title: 'Эффективность акций',
        subtitle: 'Статистика использования промо',
        group: 'ФИНАНСЫ И ПРОДАЖИ',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const PromoEffectivenessReportScreen())),
      ),
      _ReportItem(
        title: 'Отмены и возвраты',
        subtitle: 'Причины, потерянная выручка',
        group: 'КАЧЕСТВО И РЕСУРСЫ',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CancellationsReportScreen())),
      ),
      _ReportItem(
        title: 'Средний чек по моделям',
        subtitle: 'По маркам и моделям автомобилей',
        group: 'КАЧЕСТВО И РЕСУРСЫ',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const AverageCheckReportScreen())),
      ),
      _ReportItem(
        title: 'Популярные услуги',
        subtitle: 'Частота услуг и типов мойки',
        group: 'КАЧЕСТВО И РЕСУРСЫ',
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const PopularServicesReportScreen())),
      ),
      _ReportItem(
        title: 'Расходники',
        subtitle: 'Использование расходных материалов',
        group: 'КАЧЕСТВО И РЕСУРСЫ',
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const ConsumablesReportScreen())),
      ),
    ];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Отчёты',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: reports.asMap().entries.expand((entry) {
            final index = entry.key;
            final report = entry.value;
            final showHeader =
                index == 0 || reports[index - 1].group != report.group;
            return [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10, left: 4, top: 8),
                  child: Text(
                    report.group,
                    style: TextStyle(
                      color: AppStyles.adaptiveTextMuted(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              AdminCard(
                padding: const EdgeInsets.all(0),
                child: InkWell(
                  onTap: report.onTap,
                  borderRadius: BorderRadius.circular(AppStyles.radius),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                report.title,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyles.adaptiveTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                report.subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      AppStyles.adaptiveTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: AppStyles.adaptiveTextSecondary(context)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ];
          }).toList(),
        ),
      ),
    );
  }
}

class _ReportItem {
  final String title;
  final String subtitle;
  final String group;
  final VoidCallback onTap;

  _ReportItem({
    required this.title,
    required this.subtitle,
    required this.group,
    required this.onTap,
  });
}
