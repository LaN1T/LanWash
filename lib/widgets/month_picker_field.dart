import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lanwash/app_styles.dart';

class MonthPickerField extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onChanged;
  final String label;

  const MonthPickerField({
    super.key,
    required this.selectedMonth,
    required this.onChanged,
    this.label = 'Месяц',
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Выберите месяц',
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month));
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: AppStyles.inputDecorationFor(context, label),
        child: Text(
          DateFormat('MMMM yyyy', 'ru').format(selectedMonth),
          style: TextStyle(color: AppStyles.adaptiveTextPrimary(context)),
        ),
      ),
    );
  }
}
