import 'package:flutter/material.dart';
import '../../../app_styles.dart';

class BottomBar extends StatelessWidget {
  final int step;
  final void Function()? onAction;
  final String? selectedTimeLabel;
  const BottomBar(
      {super.key,
      required this.step,
      required this.onAction,
      this.selectedTimeLabel});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: AppStyles.adaptiveCard(context),
          border:
              Border(top: BorderSide(color: AppStyles.adaptiveBorder(context))),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, -4))
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (selectedTimeLabel != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppStyles.adaptivePrimaryBg(context),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppStyles.primary.withValues(alpha: 0.1)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.event_rounded,
                    color: AppStyles.primary, size: 16),
                const SizedBox(width: 8),
                Text('Выбранное время: $selectedTimeLabel',
                    style: const TextStyle(
                        color: AppStyles.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: AppStyles.primaryButton,
              onPressed: onAction,
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(
                    step == 0
                        ? 'Далее: выбор времени'
                        : step == 1
                            ? 'Далее: подтверждение'
                            : 'Записаться',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Icon(
                    step == 2
                        ? Icons.check_circle_outline_rounded
                        : Icons.arrow_forward_rounded,
                    size: 18),
              ]),
            ),
          ),
        ]),
      );
}
