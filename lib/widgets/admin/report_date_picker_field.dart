import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lanwash/app_styles.dart';

class ReportDatePickerField extends StatelessWidget {
  final String label;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onChanged;

  const ReportDatePickerField({
    super.key,
    required this.label,
    required this.selectedDate,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _pick(context),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: AppStyles.inputDecorationFor(context, label),
        child: Text(
          DateFormat('dd.MM.yyyy', 'ru').format(selectedDate),
          style: TextStyle(color: AppStyles.adaptiveTextPrimary(context)),
        ),
      ),
    );
  }
}
