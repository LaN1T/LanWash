import 'package:flutter/material.dart';
import 'app_styles.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.light(
        primary: AppStyles.primary,
        secondary: AppStyles.primaryLight,
        surface: AppStyles.bgCard,
        surfaceVariant: AppStyles.bgPage,
      ),
      useMaterial3: true,
      scaffoldBackgroundColor: AppStyles.bgPage,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppStyles.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppStyles.border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppStyles.primaryBg,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => s
                .contains(WidgetState.selected)
            ? const TextStyle(
                color: AppStyles.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600)
            : const TextStyle(color: AppStyles.textSecondary, fontSize: 12)),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? AppStyles.primary
                : AppStyles.textSecondary)),
      ),
      dividerColor: AppStyles.border,
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
            color: AppStyles.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold),
        contentTextStyle:
            TextStyle(color: AppStyles.textSecondary, fontSize: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppStyles.textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppStyles.primary
                : Colors.transparent),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(color: AppStyles.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppStyles.primary
                : AppStyles.border),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: AppStyles.primary,
        unselectedLabelColor: AppStyles.textSecondary,
        indicatorColor: AppStyles.primary,
        dividerColor: AppStyles.border,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        headerBackgroundColor: AppStyles.primary,
        headerForegroundColor: Colors.white,
        dayForegroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? Colors.white
                : AppStyles.textPrimary),
        dayBackgroundColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppStyles.primary
                : Colors.transparent),
        todayForegroundColor: WidgetStateProperty.all(AppStyles.primary),
        todayBackgroundColor: WidgetStateProperty.all(AppStyles.primaryBg),
      ),
    );
  }
}
