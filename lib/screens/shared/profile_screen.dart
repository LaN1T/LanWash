import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../utils/plate_formatter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey    = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _carModelCtrl;
  late TextEditingController _carNumberCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _passConfirmCtrl;

  bool _saving       = false;
  bool _showPass     = false;
  bool _changePass   = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl       = TextEditingController(text: user?.displayName ?? '');
    _phoneCtrl      = TextEditingController(text: user?.phone       ?? '');
    _carModelCtrl   = TextEditingController(text: user?.carModel    ?? '');
    _carNumberCtrl  = TextEditingController(text: user?.carNumber   ?? '');
    _usernameCtrl   = TextEditingController(text: user?.username    ?? '');
    _passCtrl       = TextEditingController();
    _passConfirmCtrl= TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl,_phoneCtrl,_carModelCtrl,_carNumberCtrl,
                     _usernameCtrl,_passCtrl,_passConfirmCtrl]) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_changePass && _passCtrl.text != _passConfirmCtrl.text) {
      _showSnack('Пароли не совпадают', isError: true);
      return;
    }
    setState(() => _saving = true);
    await context.read<AuthProvider>().updateProfile(
      displayName: _nameCtrl.text.trim(),
      phone:       _phoneCtrl.text.trim(),
      carModel:    _carModelCtrl.text.trim(),
      carNumber:   _carNumberCtrl.text.trim().toUpperCase(),
      newPassword: _changePass && _passCtrl.text.isNotEmpty
          ? _passCtrl.text : null,
    );
    setState(() => _saving = false);
    if (mounted) _showSnack('Профиль сохранён');
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppStyles.danger : AppStyles.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;

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
        title: const Text('Профиль',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                color: AppStyles.textPrimary)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Аватар
            Center(
              child: Column(children: [
                Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppStyles.primaryGradient,
                  ),
                  child: Icon(isAdmin ? Icons.admin_panel_settings_rounded
                      : Icons.person_rounded,
                      color: Colors.white, size: 38),
                ),
                const SizedBox(height: 12),
                Text(auth.username,
                    style: const TextStyle(color: AppStyles.textPrimary,
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppStyles.primaryBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(isAdmin ? 'Администратор' : 'Клиент',
                      style: const TextStyle(color: AppStyles.primary,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 28),

            _sectionLabel('Основные данные'),
            const SizedBox(height: 10),

            TextFormField(
              controller: _nameCtrl,
              style: const TextStyle(color: AppStyles.textPrimary),
              decoration: AppStyles.inputDecoration('Имя',
                  icon: Icons.person_outline_rounded),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _usernameCtrl,
              enabled: false, // логин менять нельзя
              style: const TextStyle(color: AppStyles.textSecondary),
              decoration: AppStyles.inputDecoration('Логин',
                  icon: Icons.alternate_email_rounded),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text('Логин нельзя изменить',
                  style: TextStyle(color: AppStyles.textMuted, fontSize: 11)),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneCtrl,
              style: const TextStyle(color: AppStyles.textPrimary),
              decoration: AppStyles.inputDecoration('Номер телефона',
                  hint: '+7 999 000-00-00',
                  icon: Icons.phone_outlined),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 24),

            if (!isAdmin) ...[ // Данные авто только для клиентов
              _sectionLabel('Данные автомобиля'),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 2, bottom: 10),
                child: Text('Будут автоматически заполняться при записи',
                    style: TextStyle(color: AppStyles.textSecondary,
                        fontSize: 12)),
              ),

              TextFormField(
                controller: _carModelCtrl,
                style: const TextStyle(color: AppStyles.textPrimary),
                decoration: AppStyles.inputDecoration('Марка и модель авто',
                    hint: 'Toyota Camry',
                    icon: Icons.directions_car_outlined),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _carNumberCtrl,
                style: const TextStyle(
                    color: AppStyles.textPrimary,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600),
                decoration: _plateDecoration(),
                inputFormatters: [PlateInputFormatter()],
              ),
              const SizedBox(height: 24),
            ],

            _sectionLabel('Безопасность'),
            const SizedBox(height: 10),

            Container(
              decoration: AppStyles.cardDecoration,
              child: SwitchListTile(
                title: const Text('Изменить пароль',
                    style: TextStyle(color: AppStyles.textPrimary,
                        fontSize: 14, fontWeight: FontWeight.w500)),
                subtitle: const Text('Задать новый пароль для входа',
                    style: TextStyle(color: AppStyles.textSecondary,
                        fontSize: 12)),
                value: _changePass,
                activeColor: AppStyles.primary,
                onChanged: (v) => setState(() {
                  _changePass = v;
                  if (!v) { _passCtrl.clear(); _passConfirmCtrl.clear(); }
                }),
              ),
            ),

            if (_changePass) ...[ 
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: !_showPass,
                style: const TextStyle(color: AppStyles.textPrimary),
                decoration: AppStyles.inputDecoration('Новый пароль',
                    icon: Icons.lock_outline_rounded),
                validator: _changePass
                    ? (v) => (v == null || v.length < 4)
                        ? 'Минимум 4 символа' : null
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passConfirmCtrl,
                obscureText: !_showPass,
                style: const TextStyle(color: AppStyles.textPrimary),
                decoration: AppStyles.inputDecoration('Повторите пароль',
                    icon: Icons.lock_outline_rounded),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => setState(() => _showPass = !_showPass),
                child: Row(children: [
                  const SizedBox(width: 4),
                  Icon(_showPass ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                      size: 16, color: AppStyles.textSecondary),
                  const SizedBox(width: 6),
                  Text(_showPass ? 'Скрыть пароль' : 'Показать пароль',
                      style: const TextStyle(color: AppStyles.textSecondary,
                          fontSize: 12)),
                ]),
              ),
            ],

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppStyles.primaryButton,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Сохранить изменения',
                        style: TextStyle(fontSize: 15,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
          color: AppStyles.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1));

  InputDecoration _plateDecoration() {
    final base = AppStyles.inputDecoration('Гос. номер',
        icon: Icons.pin_outlined);
    return base.copyWith(
      helperText: 'Формат: А000АА777',
      helperStyle: const TextStyle(
          color: AppStyles.textSecondary, fontSize: 11),
    );
  }
}
