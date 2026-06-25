import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({
    super.key,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppStyles.statusColor(status);
    final label = AppStyles.statusLabel(status);
    final icon = AppStyles.statusIcon(status);

    return Container(
      decoration: AppStyles.cardDecorationFor(context),
      padding: AppStyles.cardPadding,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppStyles.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Статус',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
