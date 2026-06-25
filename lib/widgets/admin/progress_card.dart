import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/models/consumable.dart';

extension ConsumableStock on Consumable {
  double get maxStock => minStock > 0 ? minStock * 3 : 1.0;

  double get stockProgress =>
      maxStock > 0 ? (currentStock / maxStock).clamp(0.0, 1.0) : 1.0;

  int get fillPercent => (stockProgress * 100).toInt();
}

class ProgressCard extends StatelessWidget {
  final Consumable consumable;
  final VoidCallback onRefill;
  final VoidCallback? onTap;

  const ProgressCard({
    super.key,
    required this.consumable,
    required this.onRefill,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = consumable.isLowStock;
    final accentColor = isLow ? AppStyles.danger : AppStyles.primary;
    final cardBackground = AppStyles.adaptiveCard(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppStyles.radius),
      child: Container(
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(AppStyles.radius),
          border: Border.all(color: AppStyles.adaptiveBorder(context)),
          boxShadow: AppStyles.isDark(context)
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppStyles.primary.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppStyles.radius),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: accentColor, width: 5),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            consumable.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppStyles.adaptiveTextPrimary(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            consumable.unit,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppStyles.adaptiveTextSecondary(context),
                            ),
                          ),
                          if (isLow) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppStyles.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Низкий запас',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppStyles.danger,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    isLow
                        ? ElevatedButton(
                            onPressed: onRefill,
                            style: AppStyles.primaryButton.copyWith(
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                            ),
                            child: const Text(
                              'Пополнить',
                              style: TextStyle(fontSize: 12),
                            ),
                          )
                        : OutlinedButton(
                            onPressed: onRefill,
                            style: AppStyles.outlineButton.copyWith(
                              foregroundColor: const WidgetStatePropertyAll(
                                  AppStyles.primary),
                              backgroundColor:
                                  WidgetStatePropertyAll(cardBackground),
                              side: const WidgetStatePropertyAll(
                                BorderSide(color: AppStyles.primary),
                              ),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                              ),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            child: const Text(
                              'Пополнить',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${consumable.currentStock}',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        consumable.unit,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppStyles.adaptiveTextSecondary(context),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'мин. ${consumable.minStock} ${consumable.unit}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: consumable.stockProgress,
                          backgroundColor: AppStyles.adaptiveBorder(context),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                          minHeight: 5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${consumable.fillPercent}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
