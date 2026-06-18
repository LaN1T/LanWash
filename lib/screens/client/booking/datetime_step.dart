import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app_styles.dart';

class DateTimeStep extends StatelessWidget {
  final DateTime selectedDate;
  final int selectedSlot;
  final bool weekendOnly;
  final bool Function(DateTime) isDateAllowed;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<int> onSlotChanged;
  final bool Function(DateTime, int) isSlotAvailable;
  final int Function() getDuration;
  final DateTime Function() getFinalDateTime;

  const DateTimeStep({
    super.key,
    required this.selectedDate,
    required this.selectedSlot,
    required this.weekendOnly,
    required this.isDateAllowed,
    required this.onDateChanged,
    required this.onSlotChanged,
    required this.isSlotAvailable,
    required this.getDuration,
    required this.getFinalDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final days =
        List.generate(14, (i) => DateTime.now().add(Duration(days: i)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (weekendOnly)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppStyles.warningBg,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppStyles.warning.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppStyles.warning, size: 16),
              SizedBox(width: 8),
              Text('Акция доступна только по выходным',
                  style: TextStyle(
                      color: AppStyles.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        Text('Выберите дату',
            style: AppStyles.headingMedium
                .copyWith(color: AppStyles.adaptiveTextPrimary(context))),
        const SizedBox(height: 16),
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            itemBuilder: (_, i) {
              final d = days[i];
              final sel =
                  d.day == selectedDate.day && d.month == selectedDate.month;
              final allowed = isDateAllowed(d);
              return GestureDetector(
                onTap: allowed ? () => onDateChanged(d) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 62,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppStyles.primary
                        : !allowed
                            ? AppStyles.adaptiveInnerCard(context)
                            : AppStyles.adaptiveCard(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: sel
                            ? AppStyles.primary
                            : AppStyles.adaptiveBorder(context)),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color:
                                    AppStyles.primary.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3))
                          ]
                        : [],
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(DateFormat('EE', 'ru').format(d).toUpperCase(),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: sel
                                    ? Colors.white70
                                    : !allowed
                                        ? AppStyles.adaptiveTextMuted(context)
                                        : AppStyles.adaptiveTextSecondary(
                                            context))),
                        const SizedBox(height: 4),
                        Text('${d.day}',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: sel
                                    ? Colors.white
                                    : !allowed
                                        ? AppStyles.adaptiveTextMuted(context)
                                        : AppStyles.adaptiveTextPrimary(
                                            context))),
                        Text(DateFormat('MMM', 'ru').format(d),
                            style: TextStyle(
                                fontSize: 11,
                                color: sel
                                    ? Colors.white70
                                    : !allowed
                                        ? AppStyles.adaptiveTextMuted(context)
                                        : AppStyles.adaptiveTextSecondary(
                                            context))),
                      ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        Text('Выберите время',
            style: AppStyles.headingMedium
                .copyWith(color: AppStyles.adaptiveTextPrimary(context))),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
          ),
          itemCount: (22 - 8) * 2, // 08:00 - 21:30
          itemBuilder: (_, index) {
            final hour = 8 + (index ~/ 2);
            final minute = (index % 2) * 30;
            final startMinutes = hour * 60 + minute;
            final duration = getDuration();
            final endMinutes = startMinutes + duration + 5;

            final overflow = endMinutes > 22 * 60 ? endMinutes - (22 * 60) : 0;
            final isTooLong = overflow > 480;

            final time = DateTime(selectedDate.year, selectedDate.month,
                selectedDate.day, hour, minute);
            final busy = isSlotAvailable(time, duration);
            final sel = index == selectedSlot;

            return GestureDetector(
              onTap: (!isTooLong && (busy || overflow > 0))
                  ? () => onSlotChanged(index)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sel
                      ? AppStyles.primary
                      : ((busy || overflow > 0) && !isTooLong
                          ? AppStyles.adaptiveCard(context)
                          : AppStyles.adaptiveInnerCard(context)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel
                        ? AppStyles.primary
                        : (overflow > 0
                            ? const Color(0xFFE53935)
                            : AppStyles.adaptiveBorder(context)),
                    width: (sel || overflow > 0) ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FittedBox(
                      child: Text(
                          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                            color: sel
                                ? Colors.white
                                : (busy || overflow > 0
                                    ? AppStyles.adaptiveTextPrimary(context)
                                    : AppStyles.adaptiveTextMuted(context)),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                    if (overflow > 0 && !isTooLong) ...[
                      const SizedBox(height: 2),
                      FittedBox(
                        child: Text(
                            '⚠ Завтра до ${((8 * 60 + overflow) ~/ 60).toString().padLeft(2, '0')}:${((8 * 60 + overflow) % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                                color: Color(0xFFE53935),
                                fontSize: 9,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}
