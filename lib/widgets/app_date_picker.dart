import 'package:flutter/material.dart';
import '../app_styles.dart';

/// Универсальный DatePicker с адаптивной темой (светлая / тёмная).
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  Locale? locale,
  bool Function(DateTime)? selectableDayPredicate,
  DatePickerMode initialDatePickerMode = DatePickerMode.day,
}) async {
  final dark = AppStyles.isDark(context);
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    locale: locale,
    selectableDayPredicate: selectableDayPredicate,
    initialDatePickerMode: initialDatePickerMode,
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: dark
            ? const ColorScheme.dark(
                primary: AppStyles.primary,
                onPrimary: Colors.white,
                surface: Color(0xFF1E293B),
                onSurface: Colors.white,
                surfaceContainerHighest: Color(0xFF334155),
              )
            : const ColorScheme.light(
                primary: AppStyles.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
                surfaceContainerHighest: Color(0xFFF1F5F9),
              ),
      ),
      child: child!,
    ),
  );
}

/// Универсальный TimePicker с адаптивной темой.
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
}) async {
  final dark = AppStyles.isDark(context);
  return showTimePicker(
    context: context,
    initialTime: initialTime,
    initialEntryMode: initialEntryMode,
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: dark
            ? const ColorScheme.dark(
                primary: AppStyles.primary,
                onPrimary: Colors.white,
                surface: Color(0xFF1E293B),
                onSurface: Colors.white,
                surfaceContainerHighest: Color(0xFF334155),
              )
            : const ColorScheme.light(
                primary: AppStyles.primary,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
                surfaceContainerHighest: Color(0xFFF1F5F9),
              ),
      ),
      child: child!,
    ),
  );
}
