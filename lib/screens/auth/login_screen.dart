import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback? onSessionResumed;
  final bool isResume;
  const LoginScreen({super.key, this.onSessionResumed, this.isResume = false});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _loginCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fade = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slide = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _loginCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final err = await context
        .read<AuthProvider>()
        .login(_loginCtrl.text, _passCtrl.text);

    if (!mounted) return;

    if (err == null) {
      // Инициализацию перекладываем на _AppRouter (через listenable),
      // чтобы избежать конфликтов и дублирования.
      // Сбрасываем _loading чтобы кнопка не оставалась заблокированной.
      setState(() => _loading = false);
    } else {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.adaptiveBgPage(context),
      body: Container(
        decoration: const BoxDecoration(gradient: AppStyles.bgGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: FadeTransition(
                opacity: _fade,
                child: SlideTransition(
                  position: _slide,
                  child: Form(
                    key: _formKey,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      // ── Логотип ──────────────────────────────────────────
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppStyles.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppStyles.primary.withValues(alpha:0.3),
                              blurRadius: 28,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: const Icon(Icons.local_car_wash,
                            color: Colors.white, size: 44),
                      ),
                      const SizedBox(height: 24),
                      const Text('LanWash',
                          style: TextStyle(
                              color: AppStyles.adaptiveTextPrimary(context),
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      const Text('Автомобильный Premium сервис',
                          style: TextStyle(
                              color: AppStyles.adaptiveTextSecondary(context), fontSize: 15)),
                      const SizedBox(height: 36),

                      // ── Карточка формы ───────────────────────────────────
                      widget.isResume
                          ? Container(
                              padding: const EdgeInsets.all(24),
                              decoration: AppStyles.cardDecoration,
                              child: Column(
                                children: [
                                  Text(
                                      'С возвращением, ${context.read<AuthProvider>().userLogin}!',
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 20),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: AppStyles.primaryButton,
                                      onPressed: widget.onSessionResumed,
                                      child: const Text('Продолжить'),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton(
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Сменить аккаунт'),
                                          content: const Text(
                                              'Вы уверены, что хотите выйти из текущего аккаунта?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Отмена'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppStyles.danger,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8)),
                                              ),
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                context
                                                    .read<AuthProvider>()
                                                    .logout();
                                              },
                                              child: const Text('Выйти'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: const Text(
                                        'Войти под другим пользователем',
                                        style: TextStyle(
                                            color: AppStyles.adaptiveTextSecondary(context))),
                                  ),
                                ],
                              ),
                            )
                          : Container(
                              padding: const EdgeInsets.all(24),
                              decoration: AppStyles.cardDecoration,
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Вход в систему',
                                        style: TextStyle(
                                            color: AppStyles.adaptiveTextPrimary(context),
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    const Text('Введите ваши данные для входа',
                                        style: TextStyle(
                                            color: AppStyles.adaptiveTextSecondary(context),
                                            fontSize: 13)),
                                    const SizedBox(height: 20),
                                    TextFormField(
                                      controller: _loginCtrl,
                                      style: TextStyle(
                                          color: AppStyles.adaptiveTextPrimary(context)),
                                      decoration: AppStyles.inputDecorationFor(context, 
                                          'Логин',
                                          hint: 'Введите логин',
                                          icon: Icons.person_outline),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Введите логин'
                                              : null,
                                    ),
                                    const SizedBox(height: 14),
                                    TextFormField(
                                      controller: _passCtrl,
                                      obscureText: _obscure,
                                      style: TextStyle(
                                          color: AppStyles.adaptiveTextPrimary(context)),
                                      decoration: AppStyles.inputDecorationFor(context, 
                                              'Пароль',
                                              hint: 'Введите пароль',
                                              icon: Icons.lock_outline)
                                          .copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                              _obscure
                                                  ? Icons
                                                      .visibility_off_outlined
                                                  : Icons.visibility_outlined,
                                              color: AppStyles.adaptiveTextSecondary(context),
                                              size: 20),
                                          onPressed: () => setState(
                                              () => _obscure = !_obscure),
                                        ),
                                      ),
                                      validator: (v) =>
                                          (v == null || v.trim().isEmpty)
                                              ? 'Введите пароль'
                                              : null,
                                      onFieldSubmitted: (_) => _submit(),
                                    ),
                                    if (_error != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppStyles.dangerBg,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: AppStyles.danger
                                                  .withValues(alpha:0.3)),
                                        ),
                                        child: Row(children: [
                                          const Icon(Icons.error_outline,
                                              color: AppStyles.danger,
                                              size: 18),
                                          const SizedBox(width: 8),
                                          Text(_error!,
                                              style: const TextStyle(
                                                  color: AppStyles.danger,
                                                  fontSize: 13)),
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
                                                child:
                                                    CircularProgressIndicator(
                                                        color: Colors.white,
                                                        strokeWidth: 2))
                                            : const Text('Войти'),
                                      ),
                                    ),
                                  ]),
                            ),
                      const SizedBox(height: 24),

                      TextButton(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen())),
                        child: const Text(
                          'Нет аккаунта? Зарегистрироваться',
                          style:
                              TextStyle(color: AppStyles.primary, fontSize: 14),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final String role, login, pass;
  const _Hint(this.role, this.login, this.pass);

  @override
  Widget build(BuildContext context) => Row(children: [
        Text('$role: ',
            style:
                TextStyle(color: AppStyles.adaptiveTextSecondary(context), fontSize: 12)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppStyles.adaptiveBgMuted(context),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(login,
              style: TextStyle(
                  color: AppStyles.adaptiveTextPrimary(context),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600)),
        ),
        const Text(' / ',
            style: TextStyle(color: AppStyles.adaptiveTextMuted(context), fontSize: 12)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppStyles.adaptiveBgMuted(context),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(pass,
              style: TextStyle(
                  color: AppStyles.adaptiveTextPrimary(context),
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w600)),
        ),
      ]);
}
