import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/shift.dart';
import '../../models/user.dart';

class ShiftRequestCard extends StatelessWidget {
  final Shift shift;
  final User washer;
  final String status;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onUndo;
  final VoidCallback? onJump;

  const ShiftRequestCard({
    super.key,
    required this.shift,
    required this.washer,
    required this.status,
    this.onApprove,
    this.onReject,
    this.onUndo,
    this.onJump,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateTime.parse(shift.date);
    final dateLabel = DateFormat('d MMM, EEE', 'ru_RU').format(date);

    final (statusColor, statusText) = switch (status) {
      'pending' => (AppStyles.warning, 'На рассмотрении'),
      'confirmed' => (AppStyles.success, 'Одобрено'),
      'rejected' => (AppStyles.danger, 'Отклонено'),
      _ => (AppStyles.textSecondary, status),
    };

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      elevation: 0,
      color: AppStyles.adaptiveCard(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppStyles.adaptiveBorder(context)),
      ),
      child: InkWell(
        onTap: onJump,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      washer.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$dateLabel · ${shift.startTime} – ${shift.endTime}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (status == 'pending' && onApprove != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Одобрить'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppStyles.success,
                          side: const BorderSide(color: AppStyles.success),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  if (status == 'pending' &&
                      onApprove != null &&
                      onReject != null)
                    const SizedBox(width: 8),
                  if (status == 'pending' && onReject != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Отклонить'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppStyles.danger,
                          side: const BorderSide(color: AppStyles.danger),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  if (status != 'pending' && onUndo != null)
                    TextButton.icon(
                      onPressed: onUndo,
                      icon: const Icon(Icons.undo, size: 16),
                      label: const Text('Отменить'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
