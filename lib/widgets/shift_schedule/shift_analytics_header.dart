import 'package:flutter/material.dart';
import '../../app_styles.dart';

class ShiftAnalyticsHeader extends StatelessWidget {
  final double totalConfirmedHours;
  final int pendingCount;
  final int conflictCount;
  final double? utilizationPercent;

  const ShiftAnalyticsHeader({
    super.key,
    required this.totalConfirmedHours,
    required this.pendingCount,
    required this.conflictCount,
    this.utilizationPercent,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _MetricCard(
              label: 'Всего часов',
              value: totalConfirmedHours.toStringAsFixed(1),
              icon: Icons.access_time,
              color: AppStyles.primary,
            ),
            const SizedBox(width: 12),
            _MetricCard(
              label: 'На рассмотрении',
              value: pendingCount.toString(),
              icon: Icons.pending_actions,
              color: pendingCount > 0 ? AppStyles.warning : AppStyles.success,
            ),
            const SizedBox(width: 12),
            _MetricCard(
              label: 'Конфликтов',
              value: conflictCount.toString(),
              icon: Icons.warning_amber_rounded,
              color: conflictCount > 0 ? AppStyles.danger : AppStyles.success,
            ),
            const SizedBox(width: 12),
            _MetricCard(
              label: 'Загрузка',
              value: utilizationPercent != null
                  ? '${utilizationPercent!.toStringAsFixed(0)}%'
                  : '—',
              icon: Icons.trending_up,
              color: _utilizationColor(utilizationPercent),
            ),
          ],
        ),
      ),
    );
  }

  Color _utilizationColor(double? pct) {
    if (pct == null) return AppStyles.textSecondary;
    if (pct > 100) return AppStyles.danger;
    if (pct >= 80) return AppStyles.warning;
    return AppStyles.success;
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
