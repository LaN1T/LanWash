import 'package:flutter/material.dart';
import '../../../app_styles.dart';

class StepIndicator extends StatelessWidget {
  final int current;
  const StepIndicator({super.key, required this.current});
  static const _steps = ['Услуга', 'Дата и время', 'Подтверждение'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppStyles.adaptiveCard(context),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(
              child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: i ~/ 2 < current
                  ? AppStyles.primary
                  : AppStyles.adaptiveBorder(context),
              borderRadius: BorderRadius.circular(1),
            ),
          ));
        }
        final idx = i ~/ 2;
        final done = idx < current;
        final active = idx == current;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done
                  ? AppStyles.primary
                  : active
                      ? AppStyles.adaptivePrimaryBg(context)
                      : AppStyles.adaptiveInnerCard(context),
              border: Border.all(
                color: (done || active)
                    ? AppStyles.primary
                    : AppStyles.adaptiveBorder(context),
                width: active ? 2 : 1,
              ),
            ),
            child: Center(
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 14)
                    : Text('${idx + 1}',
                        style: TextStyle(
                            color: active
                                ? AppStyles.primary
                                : AppStyles.adaptiveTextSecondary(context),
                            fontSize: 13,
                            fontWeight: FontWeight.bold))),
          ),
          const SizedBox(height: 5),
          Text(_steps[idx],
              style: TextStyle(
                color: (done || active)
                    ? AppStyles.primary
                    : AppStyles.adaptiveTextMuted(context),
                fontSize: 10,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              )),
        ]);
      })),
    );
  }
}
