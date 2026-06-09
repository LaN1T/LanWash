import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../core/service_locator.dart';
import '../../models/car.dart';
import '../../services/api_service.dart';
import 'car_list_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _usernameCtrl;

  late TextEditingController _passCtrl;
  late TextEditingController _passConfirmCtrl;

  bool _saving = false;
  bool _showPass = false;
  bool _changePass = false;
  Car? _primaryCar;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _usernameCtrl = TextEditingController(text: user?.username ?? '');
    _passCtrl = TextEditingController();
    _passConfirmCtrl = TextEditingController();
    _loadPrimaryCar();
  }

  Future<void> _loadPrimaryCar() async {
    final cars = await sl<ApiService>().getCars();
    if (mounted) {
      setState(() {
        _primaryCar = cars.where((c) => c.isPrimary).firstOrNull;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_changePass && _passCtrl.text != _passConfirmCtrl.text) {
      _showSnack('Пароли не совпадают', isError: true);
      return;
    }
    setState(() => _saving = true);
    final error = await context.read<AuthProvider>().updateProfile(
          displayName: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          newPassword:
              _changePass && _passCtrl.text.isNotEmpty ? _passCtrl.text : null,
        );
    setState(() => _saving = false);
    if (mounted) {
      if (error == null) {
        _showSnack('Изменения сохранены');
        setState(() {
          _changePass = false;
          _passCtrl.clear();
          _passConfirmCtrl.clear();
        });
      } else {
        _showSnack(error, isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppStyles.danger : AppStyles.success,
    ));
  }

  @override
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _usernameCtrl,
      _passCtrl,
      _passConfirmCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAdmin = context.read<AuthProvider>().isAdmin;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: theme.dividerColor),
        ),
        title: const Text('Настройки',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Внешний вид ────────────────────────────────────────────────
            _sectionLabel('Внешний вид'),
            const SizedBox(height: 10),
            Container(
              decoration: AppStyles.cardDecorationFor(context),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Тема оформления',
                      style: TextStyle(
                          color: AppStyles.adaptiveTextPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text('Выберите режим отображения',
                      style: TextStyle(
                          color: AppStyles.adaptiveTextSecondary(context),
                          fontSize: 12)),
                  const SizedBox(height: 10),
                  _buildThemeSelector(),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ─── Основные данные ─────────────────────────────────────────────
            _sectionLabel('Основные данные'),
            const SizedBox(height: 10),

            TextFormField(
              controller: _nameCtrl,
              style: TextStyle(color: AppStyles.adaptiveTextPrimary(context)),
              decoration: AppStyles.inputDecorationFor(context, 'Имя',
                  icon: Icons.person_outline_rounded),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _usernameCtrl,
              enabled: false,
              style: TextStyle(color: AppStyles.adaptiveTextSecondary(context)),
              decoration: AppStyles.inputDecorationFor(context, 'Логин',
                  icon: Icons.alternate_email_rounded),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text('Логин нельзя изменить',
                  style: TextStyle(
                      color: AppStyles.adaptiveTextMuted(context),
                      fontSize: 11)),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneCtrl,
              style: TextStyle(color: AppStyles.adaptiveTextPrimary(context)),
              decoration: AppStyles.inputDecorationFor(
                  context, 'Номер телефона',
                  hint: '+7 999 000-00-00', icon: Icons.phone_outlined),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            if (!isAdmin) ...[
              _sectionLabel('Данные автомобиля'),
              const SizedBox(height: 10),
              if (_primaryCar != null) ...[
                Container(
                  decoration: AppStyles.cardDecorationFor(context),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppStyles.adaptivePrimaryBg(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.directions_car_outlined,
                            color: AppStyles.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _primaryCar!.displayName,
                              style: TextStyle(
                                color: AppStyles.adaptiveTextPrimary(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_primaryCar!.number.isNotEmpty)
                              Text(
                                _primaryCar!.number,
                                style: TextStyle(
                                  color: AppStyles.adaptiveTextSecondary(context),
                                  fontSize: 13,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppStyles.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Основное',
                            style: TextStyle(
                                color: AppStyles.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Container(
                decoration: AppStyles.cardDecorationFor(context),
                child: ListTile(
                  leading: const Icon(Icons.garage_outlined,
                      color: AppStyles.primary, size: 22),
                  title: Text('Мои автомобили',
                      style: TextStyle(
                          color: AppStyles.adaptiveTextPrimary(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  subtitle: Text('Управление автомобилями',
                      style: TextStyle(
                          color: AppStyles.adaptiveTextSecondary(context),
                          fontSize: 12)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppStyles.adaptiveTextMuted(context)),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const CarListScreen()),
                    );
                    _loadPrimaryCar();
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Безопасность ───────────────────────────────────────────────
            _sectionLabel('Безопасность'),
            const SizedBox(height: 10),
            Container(
              decoration: AppStyles.cardDecorationFor(context),
              child: SwitchListTile(
                title: Text('Изменить пароль',
                    style: TextStyle(
                        color: AppStyles.adaptiveTextPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Задать новый пароль для входа',
                    style: TextStyle(
                        color: AppStyles.adaptiveTextSecondary(context),
                        fontSize: 12)),
                value: _changePass,
                activeThumbColor: AppStyles.primary,
                onChanged: (v) => setState(() {
                  _changePass = v;
                  if (!v) {
                    _passCtrl.clear();
                    _passConfirmCtrl.clear();
                  }
                }),
              ),
            ),
            if (_changePass) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: !_showPass,
                style: TextStyle(color: AppStyles.adaptiveTextPrimary(context)),
                decoration: AppStyles.inputDecorationFor(
                    context, 'Новый пароль',
                    icon: Icons.lock_outline_rounded),
                validator: AppValidators.password,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passConfirmCtrl,
                obscureText: !_showPass,
                style: TextStyle(color: AppStyles.adaptiveTextPrimary(context)),
                decoration: AppStyles.inputDecorationFor(
                    context, 'Повторите пароль',
                    icon: Icons.lock_outline_rounded),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _showPass = !_showPass),
                child: Row(children: [
                  const SizedBox(width: 4),
                  Icon(
                      _showPass
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 16,
                      color: AppStyles.adaptiveTextSecondary(context)),
                  const SizedBox(width: 6),
                  Text(_showPass ? 'Скрыть пароль' : 'Показать пароль',
                      style: TextStyle(
                          color: AppStyles.adaptiveTextSecondary(context),
                          fontSize: 12)),
                ]),
              ),
            ],
            const SizedBox(height: 28),

            // ─── Аккаунт ────────────────────────────────────────────────────
            _sectionLabel('Аккаунт'),
            const SizedBox(height: 10),
            Container(
              decoration: AppStyles.cardDecorationFor(context),
              child: ListTile(
                leading: const Icon(Icons.logout_outlined,
                    color: AppStyles.danger, size: 22),
                title: const Text('Выйти из аккаунта',
                    style: TextStyle(
                        color: AppStyles.danger,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Вы вернётесь на экран входа',
                    style: TextStyle(
                        color: AppStyles.adaptiveTextSecondary(context),
                        fontSize: 12)),
                onTap: _confirmLogout,
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppStyles.primaryButton,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Сохранить изменения',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          color: AppStyles.adaptiveTextSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1));

  Widget _buildThemeSelector() {
    final themeProvider = context.watch<ThemeProvider>();
    final effectiveMode = themeProvider.appThemeMode == AppThemeMode.system
        ? AppThemeMode.light
        : themeProvider.appThemeMode;
    return SegmentedButton<AppThemeMode>(
      segments: const [
        ButtonSegment(
          value: AppThemeMode.light,
          label: Text('Светлая', style: TextStyle(fontSize: 12)),
          icon: Icon(Icons.wb_sunny, size: 18),
        ),
        ButtonSegment(
          value: AppThemeMode.dark,
          label: Text('Тёмная', style: TextStyle(fontSize: 12)),
          icon: Icon(Icons.dark_mode, size: 18),
        ),
      ],
      selected: {effectiveMode},
      onSelectionChanged: (selection) {
        if (selection.isNotEmpty) {
          themeProvider.setMode(selection.first);
        }
      },
      style: ButtonStyle(
        padding:
            WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8)),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Выйти из аккаунта?',
            style: TextStyle(color: AppStyles.adaptiveTextPrimary(context))),
        content: Text('Вы вернётесь на экран входа.',
            style: TextStyle(color: AppStyles.adaptiveTextSecondary(context))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Отмена',
                  style: TextStyle(
                      color: AppStyles.adaptiveTextSecondary(context)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(context);
              context.read<AuthProvider>().logout();
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}
