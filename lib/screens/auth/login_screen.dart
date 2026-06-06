import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
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
    return Scaffold(
        backgroundColor: AppStyles.adaptiveBgPage(context),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                  gradient: AppStyles.adaptiveBgGradient(context)),
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
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            // ── Логотип ──────────────────────────────────────────
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppStyles.primaryGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppStyles.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: const Icon(Icons.local_car_wash,
                                  color: Colors.white, size: 44),
                            ),
                            const SizedBox(height: 24),
                            Text(lang.tr('app_name'),
                                style: TextStyle(
                                    color:
                                        AppStyles.adaptiveTextPrimary(context),
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5)),
                            const SizedBox(height: 6),
                            Text('Автомобильный Premium сервис',
                                style: TextStyle(
                                    color: AppStyles.adaptiveTextSecondary(
                                        context),
                                    fontSize: 15)),
                            const SizedBox(height: 36),

                            // ── Карточка формы ───────────────────────────────────
                            widget.isResume
                                ? Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration:
                                        AppStyles.cardDecorationFor(context),
                                    child: Column(
                                      children: [
                                        Text(
                                            '${lang.tr('login_resume_title')}, ${context.read<AuthProvider>().userLogin}!',
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            style: AppStyles.primaryButton,
                                            onPressed: widget.onSessionResumed,
                                            child: Text(
                                                lang.tr('login_resume_button')),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        TextButton(
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text(lang.tr(
                                                    'login_switch_dialog_title')),
                                                content: Text(lang.tr(
                                                    'login_switch_dialog_body')),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                    child:
                                                        Text(lang.tr('cancel')),
                                                  ),
                                                  ElevatedButton(
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor:
                                                          AppStyles.danger,
                                                      foregroundColor:
                                                          Colors.white,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.pop(ctx);
                                                      context
                                                          .read<AuthProvider>()
                                                          .logout();
                                                    },
                                                    child:
                                                        Text(lang.tr('logout')),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: Text(
                                              lang.tr('login_switch_account'),
                                              style: TextStyle(
                                                  color: AppStyles
                                                      .adaptiveTextSecondary(
                                                          context))),
                                        ),
                                      ],
                                    ),
                                  )
                                : Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration:
                                        AppStyles.cardDecorationFor(context),
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(lang.tr('login_title'),
                                              style: TextStyle(
                                                  color: AppStyles
                                                      .adaptiveTextPrimary(
                                                          context),
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 6),
                                          Text(lang.tr('login_subtitle'),
                                              style: TextStyle(
                                                  color: AppStyles
                                                      .adaptiveTextSecondary(
                                                          context),
                                                  fontSize: 13)),
                                          const SizedBox(height: 20),
                                          TextFormField(
                                            controller: _loginCtrl,
                                            style: TextStyle(
                                                color: AppStyles
                                                    .adaptiveTextPrimary(
                                                        context)),
                                            decoration:
                                                AppStyles.inputDecorationFor(
                                                    context,
                                                    lang.tr(
                                                        'login_field_login'),
                                                    hint: lang.tr(
                                                        'login_field_login_hint'),
                                                    icon: Icons.person_outline),
                                            validator: (v) => (v == null ||
                                                    v.trim().isEmpty)
                                                ? lang.tr('validation_required')
                                                : null,
                                          ),
                                          const SizedBox(height: 14),
                                          TextFormField(
                                            controller: _passCtrl,
                                            obscureText: _obscure,
                                            style: TextStyle(
                                                color: AppStyles
                                                    .adaptiveTextPrimary(
                                                        context)),
                                            decoration: AppStyles.inputDecorationFor(
                                                    context,
                                                    lang.tr(
                                                        'login_field_password'),
                                                    hint: lang.tr(
                                                        'login_field_password_hint'),
                                                    icon: Icons.lock_outline)
                                                .copyWith(
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                    _obscure
                                                        ? Icons
                                                            .visibility_off_outlined
                                                        : Icons
                                                            .visibility_outlined,
                                                    color: AppStyles
                                                        .adaptiveTextSecondary(
                                                            context),
                                                    size: 20),
                                                onPressed: () => setState(
                                                    () => _obscure = !_obscure),
                                              ),
                                            ),
                                            validator: (v) => (v == null ||
                                                    v.trim().isEmpty)
                                                ? lang.tr('validation_required')
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
                                                        .withValues(
                                                            alpha: 0.3)),
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
                                              onPressed:
                                                  _loading ? null : _submit,
                                              child: _loading
                                                  ? const SizedBox(
                                                      width: 20,
                                                      height: 20,
                                                      child:
                                                          CircularProgressIndicator(
                                                              color:
                                                                  Colors.white,
                                                              strokeWidth: 2))
                                                  : Text(
                                                      lang.tr('login_button')),
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
                              child: Text(
                                lang.tr('login_no_account'),
                                style: const TextStyle(
                                    color: AppStyles.primary, fontSize: 14),
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
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLanguageButton(),
                    _buildThemeButton(),
                  ],
                ),
              ),
            ),
          ],
        ));
  }
}
