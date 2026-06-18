import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../app_styles.dart';
import '../../models/shift_load_report.dart';

class ShiftAnalyticsView extends StatelessWidget {
  final ShiftLoadReport report;

  const ShiftAnalyticsView({
    super.key,
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildKpiRow(context),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Часы по дням недели'),
        const SizedBox(height: 12),
        SizedBox(height: 220, child: _buildDailyChart(context)),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Загрузка по мойщикам'),
        const SizedBox(height: 12),
        _buildWasherStats(context),
        const SizedBox(height: 24),
        _buildSectionTitle(context, 'Доступность мойщиков'),
        const SizedBox(height: 12),
        _buildAvailabilityChips(),
      ],
    );
  }

  Widget _buildKpiRow(BuildContext context) {
    final totalConfirmed = report.washerStats.fold<int>(
      0,
      (sum, s) => sum + s.confirmedMinutes,
    );
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _kpiCard(
          context,
          'Всего часов',
          '${(totalConfirmed / 60).toStringAsFixed(1)} ч',
          AppStyles.primary,
        ),
        _kpiCard(
          context,
          'На рассмотрении',
          '${report.statusCounts.pending}',
          report.statusCounts.pending > 0
              ? AppStyles.warning
              : AppStyles.success,
        ),
        _kpiCard(
          context,
          'Конфликтов',
          '${report.conflictCount}',
          report.conflictCount > 0 ? AppStyles.danger : AppStyles.success,
        ),
        _kpiCard(
          context,
          'Перегрузок',
          '${report.washerStats.where((s) => s.isOvertime).length}',
          report.washerStats.any((s) => s.isOvertime)
              ? AppStyles.danger
              : AppStyles.success,
        ),
      ],
    );
  }

  Widget _kpiCard(
      BuildContext context, String title, String value, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppStyles.adaptiveTextSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppStyles.adaptiveTextPrimary(context),
      ),
    );
  }

  Widget _buildDailyChart(BuildContext context) {
    final maxY = report.dailyHours
            .map((e) => (e.confirmedMinutes + e.pendingMinutes) / 60.0)
            .fold<double>(0, (m, v) => v > m ? v : m) *
        1.2;
    return BarChart(
      BarChartData(
        maxY: maxY < 4 ? 4 : maxY,
        barGroups: report.dailyHours.asMap().entries.map((entry) {
          final index = entry.key;
          final day = entry.value;
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: day.confirmedMinutes / 60.0,
                color: AppStyles.success,
                width: 14,
                borderRadius: BorderRadius.circular(4),
              ),
              BarChartRodData(
                toY: (day.confirmedMinutes + day.pendingMinutes) / 60.0,
                color: AppStyles.warning,
                width: 14,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }).toList(),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final index = value.toInt();
                if (index < 0 || index >= report.dailyHours.length) {
                  return const SizedBox.shrink();
                }
                final date = DateTime.parse(report.dailyHours[index].date);
                return Text(
                  DateFormat('E', 'ru_RU').format(date),
                  style: TextStyle(
                    fontSize: 10,
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()} ч',
                style: TextStyle(
                  fontSize: 10,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
              ),
            ),
          ),
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildWasherStats(BuildContext context) {
    if (report.washerStats.isEmpty) {
      return const Text('Нет данных по мойщикам');
    }
    final maxMinutes = report.targetWeeklyMinutesPerWasher;
    return Column(
      children: report.washerStats.map((stat) {
        final ratio = maxMinutes > 0
            ? (stat.confirmedMinutes / maxMinutes).clamp(0.0, 1.0)
            : 0.0;
        final color = stat.isOvertime
            ? AppStyles.danger
            : stat.isUnderload
                ? AppStyles.warning
                : AppStyles.success;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stat.displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.adaptiveTextPrimary(context),
                      ),
                    ),
                  ),
                  Text(
                    '${(stat.confirmedMinutes / 60).toStringAsFixed(1)} ч · ${stat.utilizationPercent.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.adaptiveTextSecondary(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAvailabilityChips() {
    final coverage = report.availabilityCoverage;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _chip('Доступны', coverage.availableDays.toString(), AppStyles.success),
        _chip('Недоступны', coverage.unavailableDays.toString(),
            AppStyles.danger),
        _chip('Не указано', coverage.unknownDays.toString(), Colors.grey),
      ],
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$label: $value',
            style: TextStyle(
                fontSize: 12, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
