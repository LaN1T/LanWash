import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/widgets/admin/report_date_picker_field.dart';
import 'package:lanwash/widgets/month_picker_field.dart';

enum ReportPeriodMode { month, day }

class ReportPeriodPicker extends StatelessWidget {
  final ReportPeriodMode mode;
  final ValueChanged<ReportPeriodMode> onModeChanged;
  final DateTime selectedMonth;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDayChanged;

  const ReportPeriodPicker({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.selectedMonth,
    required this.selectedDay,
    required this.onMonthChanged,
    required this.onDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ReportPeriodMode>(
            segments: const [
              ButtonSegment(
                value: ReportPeriodMode.month,
                label: Text('Весь месяц'),
              ),
              ButtonSegment(
                value: ReportPeriodMode.day,
                label: Text('Конкретный день'),
              ),
            ],
            selected: <ReportPeriodMode>{mode},
            onSelectionChanged: (selected) {
              if (selected.isNotEmpty) onModeChanged(selected.first);
            },
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppStyles.primary,
              selectedForegroundColor: Colors.white,
              foregroundColor: AppStyles.adaptiveTextSecondary(context),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: mode == ReportPeriodMode.month
              ? MonthPickerField(
                  label: 'Месяц',
                  selectedMonth: selectedMonth,
                  onChanged: onMonthChanged,
                )
              : ReportDatePickerField(
                  label: 'День',
                  selectedDate: selectedDay,
                  onChanged: onDayChanged,
                ),
        ),
      ],
    );
  }
}
