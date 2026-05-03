import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_styles.dart';
import '../providers/auth_provider.dart';
import '../providers/app_provider.dart';

// ─── Маска телефона: +7 (999) 000-00-00 ──────────────────────────────────────
class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    // Нормализуем: всегда 7 в начале
    if (digits.startsWith('8') || digits.startsWith('7')) {
      digits = '7' + digits.substring(1);
    } else if (digits.isNotEmpty) {
      digits = '7' + digits;
    } else {
      return newValue.copyWith(text: '+7', selection: const TextSelection.collapsed(offset: 2));
    }
    final buf = StringBuffer('+7');
    if (digits.length > 1) {
      final area = digits.substring(1, digits.length.clamp(1, 4));
      buf.write(' ($area');
      if (digits.length >= 4) buf.write(') ');
    }
    if (digits.length > 4) buf.write(digits.substring(4, digits.length.clamp(4, 7)));
    if (digits.length > 7) buf.write('-${digits.substring(7, digits.length.clamp(7, 9))}');
    if (digits.length > 9) buf.write('-${digits.substring(9, digits.length.clamp(9, 11))}');
    final result = buf.toString();
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _loginCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _nameCtrl   = TextEditingController();
  final _phoneCtrl  = TextEditingController(text: '+7');
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _loginCtrl.dispose(); _passCtrl.dispose();
    _nameCtrl.dispose(); _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final auth = context.read<AuthProvider>();
    final err = await auth.register(
      username: _loginCtrl.text.trim(),
      password: _passCtrl.text.trim(),
      displayName: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );

    if (!mounted) return;
    if (err != null) {
      setState(() { _loading = false; _error = err; });
      return;
    }

    // Успешная регистрация — загружаем данные и уходим на корень (_AppRouter покажет ClientShell)
    await context.read<AppProvider>().reloadForUser(auth.userLogin, auth);
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.border),
        ),
        title: const Text('Регистрация'),
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
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppStyles.primaryGradient,
                    boxShadow: [BoxShadow(
                      color: AppStyles.primary.withOpacity(0.25),
                      blurRadius: 20,
                    )],
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                const Text('Создать аккаунт', style: AppStyles.headingLarge),
                const SizedBox(height: 6),
                const Text('Заполните данные для регистрации',
                    style: AppStyles.bodyMedium),
                const SizedBox(height: 28),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppStyles.cardDecoration,
                  child: Column(children: [
                    TextFormField(
                      controller: _nameCtrl,
                      style: const TextStyle(color: AppStyles.textPrimary),
                      decoration: AppStyles.inputDecoration('Ваше имя',
                          icon: Icons.person_outline_rounded),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Введите имя' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _loginCtrl,
                      style: const TextStyle(color: AppStyles.textPrimary),
                      decoration: AppStyles.inputDecoration('Логин',
                          hint: 'только латиница и цифры',
                          icon: Icons.alternate_email_rounded),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Введите логин';
                        if (v.trim().length < 3) return 'Минимум 3 символа';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      style: const TextStyle(color: AppStyles.textPrimary),
                      decoration: AppStyles.inputDecoration('Пароль',
                          icon: Icons.lock_outline_rounded).copyWith(
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                              color: AppStyles.textSecondary, size: 20),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Введите пароль';
                        if (v.length < 4) return 'Минимум 4 символа';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _phoneCtrl,
                      style: const TextStyle(color: AppStyles.textPrimary),
                      decoration: AppStyles.inputDecoration('Телефон',
                          hint: '+7 (999) 000-00-00',
                          icon: Icons.phone_outlined),
                      keyboardType: TextInputType.phone,
                      inputFormatters: [_PhoneInputFormatter()],
                      validator: (v) {
                        if (v == null || v.trim().length <= 2) return 'Введите телефон';
                        final digits = v.replaceAll(RegExp(r'\D'), '');
                        if (digits.length < 11) return 'Введите полный номер (+7 и 10 цифр)';
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
                              color: AppStyles.danger.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: AppStyles.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!, style: const TextStyle(
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
                            ? const SizedBox(width: 20, height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Зарегистрироваться'),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Уже есть аккаунт? Войти',
                      style: TextStyle(color: AppStyles.primary, fontSize: 14)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
