import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';

// ─── Маска телефона: +7 (999) 000-00-00 ──────────────────────────────────────
class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Нормализуем: всегда 7 в начале
    if (digits.startsWith('8') || digits.startsWith('7')) {
      digits = '7${digits.substring(1)}';
    } else if (digits.isNotEmpty) {
      digits = '7$digits';
    } else {
      return newValue.copyWith(
          text: '+7', selection: const TextSelection.collapsed(offset: 2));
    }
    final buf = StringBuffer('+7');
    if (digits.length > 1) {
      final area = digits.substring(1, digits.length.clamp(1, 4));
      buf.write(' ($area');
      if (digits.length >= 4) buf.write(') ');
    }
    if (digits.length > 4) {
      buf.write(digits.substring(4, digits.length.clamp(4, 7)));
    }
    if (digits.length > 7) {
      buf.write('-${digits.substring(7, digits.length.clamp(7, 9))}');
    }
    if (digits.length > 9) {
      buf.write('-${digits.substring(9, digits.length.clamp(9, 11))}');
    }
    final result = buf.toString();
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+7');
  final _refCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  AppLanguage? _errorLanguage;

  @override
  void dispose() {
    _loginCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    final err = await auth.register(
      username: _loginCtrl.text.trim(),
      password: _passCtrl.text,
      displayName: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      referralCode: _refCtrl.text.trim().isEmpty ? null : _refCtrl.text.trim().toUpperCase(),
    );

    if (!mounted) return;
    if (err != null) {
      final currentLang = context.read<LanguageProvider>().language;
      setState(() {
        _loading = false;
        _error = err;
        _errorLanguage = currentLang;
      });
      return;
    }

    // Успешная регистрация — загружаем данные и уходим на корень (_AppRouter покажет ClientShell)
    await context
        .read<AppointmentProvider>()
        .reloadForUser(auth.userLogin, auth);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Widget _buildThemeButton() {
    final themeProvider = context.watch<ThemeProvider>();
    final lang = context.read<LanguageProvider>();
    final isDark = themeProvider.themeMode == ThemeMode.dark ||
        (themeProvider.themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return IconButton(
      icon: Icon(
        isDark ? Icons.dark_mode_outlined : Icons.wb_sunny_outlined,
        color: AppStyles.adaptiveTextPrimary(context),
      ),
      tooltip: lang.tr('theme'),
      onPressed: () {
        themeProvider.setMode(isDark ? AppThemeMode.light : AppThemeMode.dark);
      },
    );
  }

  Widget _buildLanguageButton() {
    final lang = context.watch<LanguageProvider>();
    return IconButton(
      icon: Text(
        lang.language == AppLanguage.ru ? 'RU' : 'EN',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppStyles.adaptiveTextPrimary(context),
        ),
      ),
      tooltip: lang.tr('language'),
      onPressed: lang.toggle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    if (_error != null && _errorLanguage != lang.language) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _error = null);
      });
    }
    return Scaffold(
      backgroundColor: AppStyles.adaptiveBgPage(context),
      appBar: AppBar(
        backgroundColor: AppStyles.adaptiveBgPage(context),
        foregroundColor: AppStyles.adaptiveTextPrimary(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        title: Text('Регистрация',
            style: TextStyle(color: AppStyles.adaptiveTextPrimary(context))),
        actions: [_buildLanguageButton(), _buildThemeButton()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: Column(children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppStyles.primaryGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppStyles.primary.withValues(alpha: 0.25),
                        blurRadius: 20,
                      )
                    ],
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text(lang.tr('register_title'),
                    style: AppStyles.adaptiveHeadingLarge(context)),
                const SizedBox(height: 6),
                Text(lang.tr('register_subtitle'),
                    style: AppStyles.adaptiveBodyMedium(context)),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppStyles.cardDecorationFor(context),
                  child: Column(children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: TextStyle(
                          color: AppStyles.adaptiveTextPrimary(context)),
                      decoration: AppStyles.inputDecorationFor(
                          context, lang.tr('register_field_name'),
                          icon: Icons.person_outline_rounded),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? lang.tr('validation_required')
                          : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _emailCtrl,
                      style: TextStyle(
                          color: AppStyles.adaptiveTextPrimary(context)),
                      decoration: AppStyles.inputDecorationFor(
                          context, lang.tr('register_field_email'),
                          hint: lang.tr('register_field_email_hint'),
                          icon: Icons.email_outlined),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return null;
                        return AppValidators.validateEmail(v.trim());
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _loginCtrl,
                      style: TextStyle(
                          color: AppStyles.adaptiveTextPrimary(context)),
                      decoration: AppStyles.inputDecorationFor(
                          context, lang.tr('register_field_login'),
                          hint: lang.tr('register_field_login_hint'),
                          icon: Icons.alternate_email_rounded),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return lang.tr('validation_required');
                        }
                        if (v.trim().length < 3)
                          return lang.tr('validation_login_short');
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: TextStyle(
                          color: AppStyles.adaptiveTextPrimary(context)),
                      decoration: AppStyles.inputDecorationFor(
                              context, lang.tr('register_field_password'),
                              icon: Icons.lock_outline_rounded)
                          .copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppStyles.adaptiveTextSecondary(context),
                              size: 20),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: AppValidators.password,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _refCtrl,
                      style: TextStyle(
                          color: AppStyles.adaptiveTextPrimary(context)),
                      decoration: AppStyles.inputDecorationFor(
                          context, lang.tr('register_field_referral'),
                          hint: lang.tr('register_field_referral_hint'),
                          icon: Icons.card_giftcard_outlined),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneCtrl,
                      style: TextStyle(
                          color: AppStyles.adaptiveTextPrimary(context)),
                      decoration: AppStyles.inputDecorationFor(
                          context, lang.tr('register_field_phone'),
                          hint: lang.tr('register_field_phone_hint'),
                          icon: Icons.phone_outlined),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_PhoneInputFormatter()],
                      validator: (v) {
                        if (v == null || v.trim().length <= 2) {
                          return lang.tr('validation_required');
                        }
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 11) {
                          return lang.tr('validation_phone_short');
                        }
                        return null;
                      },
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppStyles.dangerBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: AppStyles.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: AppStyles.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: AppStyles.danger, fontSize: 13))),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: AppStyles.primaryButton,
                        onPressed: _loading ? null : _submit,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text(lang.tr('register_button')),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(lang.tr('register_has_account'),
                      style: const TextStyle(
                          color: AppStyles.primary, fontSize: 14)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
