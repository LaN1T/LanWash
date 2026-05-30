import 'package:flutter/material.dart';

class AppStyles {
  AppStyles._();

  // ─── Светлая премиум палитра ─────────────────────────────────────────────
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1240A8);
  static const Color primaryBg = Color(0xFFEFF4FF);

  static const Color bgPage = Color(0xFFF8FAFF);
  static const Color bgCard = Colors.white;
  static const Color bgMuted = Color(0xFFF1F5F9);

  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocus = Color(0xFF1A56DB);

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFFADB5C8);

  static const Color success = Color(0xFF059669);
  static const Color successBg = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFFFBEB);
  static const Color danger = Color(0xFFDC2626);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color inProgress = Color(0xFF7C3AED);
  static const Color inProgressBg = Color(0xFFF5F3FF);

  // Алиасы
  static const Color accent = primary;
  static const Color background = bgPage;
  static const Color card = bgCard;
  static const Color divider = border;
  static const Color favorite = Color(0xFFEAB308);
  static const Color apiTag = Color(0xFF0891B2);
  static const Color gold = Color(0xFFEAB308);
  static const Color blue = primary;
  static const Color blueLight = primaryLight;
  static const Color bgDark = Color(0xFF0F172A);
  static const Color bgMedium = Color(0xFF1E293B);
  static const Color textMuted2 = textMuted;

  // ─── Тёмная тема ─────────────────────────────────────────────────────────
  static const Color darkCard = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color adaptiveTextPrimary(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color adaptiveTextSecondary(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color adaptiveTextMuted(BuildContext context) =>
      isDark(context) ? darkTextMuted : textMuted;

  static Color adaptiveBorder(BuildContext context) =>
      isDark(context) ? darkBorder : border;

  static Color adaptiveCard(BuildContext context) =>
      isDark(context) ? darkCard : bgCard;

  static Color adaptiveBgMuted(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E293B) : bgMuted;

  static Color adaptiveInnerCard(BuildContext context) =>
      isDark(context) ? const Color(0xFF334155) : bgMuted;

  static Color adaptivePrimaryBg(BuildContext context) =>
      isDark(context) ? const Color(0xFF1E3A5F) : primaryBg;

  // ─── Текст ───────────────────────────────────────────────────────────────
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );
  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: textPrimary,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textSecondary,
  );
  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: textSecondary,
  );
  static const TextStyle price = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: primary,
  );
  static const TextStyle label = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    color: textSecondary,
  );

  // ─── Карточки ────────────────────────────────────────────────────────────
  static BoxDecoration cardDecoration = BoxDecoration(
    color: bgCard,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border),
    boxShadow: [
      BoxShadow(
          color: const Color(0xFF1A56DB).withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 4)),
      BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 4,
          offset: const Offset(0, 1)),
    ],
  );

  static BoxDecoration primaryCardDecoration = BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
          color: const Color(0xFF1A56DB).withOpacity(0.35),
          blurRadius: 24,
          offset: const Offset(0, 8)),
    ],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bgGradient = LinearGradient(
    colors: [Color(0xFFF8FAFF), Color(0xFFEFF4FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Для совместимости
  static const LinearGradient goldGradient = LinearGradient(
    colors: [Color(0xFF1A56DB), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient blueGradient = primaryGradient;
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Карточки (адаптивные) ──────────────────────────────────────────────
  static BoxDecoration cardDecorationFor(BuildContext context) => BoxDecoration(
        color: adaptiveCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: adaptiveBorder(context)),
        boxShadow: [
          BoxShadow(
              color: primary.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4)),
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      );

  // ─── Поля ввода ──────────────────────────────────────────────────────────
  static InputDecoration inputDecoration(String labelText,
      {String? hint, IconData? icon, bool obscure = false}) {
    return InputDecoration(
      labelText: labelText,
      hintText: hint,
      labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: textMuted, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: primary, size: 20) : null,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger)),
      filled: true,
      fillColor: bgCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  static InputDecoration inputDecorationFor(
      BuildContext context, String labelText,
      {String? hint, IconData? icon, bool obscure = false}) {
    final dark = isDark(context);
    return InputDecoration(
      labelText: labelText,
      hintText: hint,
      labelStyle: TextStyle(
          color: dark ? darkTextSecondary : textSecondary, fontSize: 14),
      hintStyle:
          TextStyle(color: dark ? darkTextMuted : textMuted, fontSize: 14),
      prefixIcon: icon != null ? Icon(icon, color: primary, size: 20) : null,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? darkBorder : border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: dark ? darkBorder : border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger)),
      filled: true,
      fillColor: adaptiveCard(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ─── Кнопки ──────────────────────────────────────────────────────────────
  static final ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );

  static final ButtonStyle goldButton = ElevatedButton.styleFrom(
    backgroundColor: primary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    elevation: 0,
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
  );

  static final ButtonStyle outlineButton = OutlinedButton.styleFrom(
    foregroundColor: primary,
    side: const BorderSide(color: primary),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  static final ButtonStyle flatButton = TextButton.styleFrom(
    foregroundColor: textSecondary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
  );

  // ─── Статусы ─────────────────────────────────────────────────────────────
  static Color statusColor(String s) => switch (s) {
        'scheduled' => primary,
        'in_progress' => inProgress,
        'completed' => success,
        'cancelled' => danger,
        _ => textSecondary,
      };

  static Color statusBgColor(String s) => switch (s) {
        'scheduled' => primaryBg,
        'in_progress' => inProgressBg,
        'completed' => successBg,
        'cancelled' => dangerBg,
        _ => bgMuted,
      };

  static String statusLabel(String s) => switch (s) {
        'scheduled' => 'Запланирована',
        'in_progress' => 'В процессе',
        'completed' => 'Завершена',
        'cancelled' => 'Отменена',
        _ => s,
      };

  static IconData statusIcon(String s) => switch (s) {
        'scheduled' => Icons.schedule_rounded,
        'in_progress' => Icons.autorenew_rounded,
        'completed' => Icons.check_circle_rounded,
        'cancelled' => Icons.cancel_rounded,
        _ => Icons.help_outline,
      };

  // ─── Размеры ─────────────────────────────────────────────────────────────
  static const double radius = 16.0;
  static const double radiusSm = 10.0;
  static const EdgeInsets pagePadding = EdgeInsets.all(16);
  static const EdgeInsets cardPadding = EdgeInsets.all(16);
}
