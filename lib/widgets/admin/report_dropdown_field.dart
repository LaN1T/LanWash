// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';

class ReportDropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const ReportDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      isExpanded: true,
      decoration: AppStyles.inputDecorationFor(context, label),
      dropdownColor: AppStyles.adaptiveCard(context),
    );
  }
}
