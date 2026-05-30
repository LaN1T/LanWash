import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../models/appointment.dart';
import '../../models/user_stats.dart';
import '../../utils/plate_formatter.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _carModelCtrl;
  late TextEditingController _carNumberCtrl;
  late TextEditingController _usernameCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _passConfirmCtrl;

  bool _saving = false;
  bool _showPass = false;
  bool _changePass = false;
  bool _uploadingAvatar = false;

  UserStats? _stats;
  bool _statsLoading = true;
  List<Appointment> _history = [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _phoneCtrl = TextEditingController(text: user?.phone ?? '');
    _carModelCtrl = TextEditingController(text: user?.carModel ?? '');
    _carNumberCtrl = TextEditingController(text: user?.carNumber ?? '');
    _usernameCtrl = TextEditingController(text: user?.username ?? '');
    _passCtrl = TextEditingController();
    _passConfirmCtrl = TextEditingController();
    _loadStats();
    _loadHistory();
  }

  Future<void> _loadStats() async {
    final username = context.read<AuthProvider>().userLogin;
    final data = await context.read<ApiService>().getUserStats(username);
    if (mounted && data != null) {
      setState(() {
        _stats = UserStats.fromMap(data);
        _statsLoading = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    final username = context.read<AuthProvider>().userLogin;
    final list =
        await context.read<ApiService>().getAppointmentsByOwner(username);
    if (mounted) {
      setState(() {
        _history = list.where((a) => a.status == 'completed').toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
        _historyLoading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final auth = context.read<AuthProvider>();
    final api = context.read<ApiService>();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.single.bytes == null) return;

    final bytes = result.files.single.bytes!;
    final filename = result.files.single.name;
    final user = auth.user;
    if (user?.id == null) return;

    setState(() => _uploadingAvatar = true);
    final url = await api.uploadAvatar(user!.id!, bytes, filename);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    if (url != null) {
      auth.updateAvatar(url);
      _showSnack('Аватар обновлён');
    }
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
          phone: _phoneCtrl.text.trim(),
          carModel: _carModelCtrl.text.trim(),
          carNumber: _carNumberCtrl.text.trim().toUpperCase(),
          newPassword:
              _changePass && _passCtrl.text.isNotEmpty ? _passCtrl.text : null,
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
  void dispose() {
    for (final c in [
      _nameCtrl,
      _phoneCtrl,
      _carModelCtrl,
      _carNumberCtrl,
      _usernameCtrl,
      _passCtrl,
      _passConfirmCtrl
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final isWasher = auth.isWasher;
    final user = auth.user;

    String roleLabel;
    if (isAdmin) {
      roleLabel = 'Администратор';
    } else if (isWasher) {
      roleLabel = 'Мойщик';
    } else {
      roleLabel = 'Клиент';
    }

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: theme.dividerColor),
        ),
        title: const Text('Профиль',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ─── Аватар + имя + уровень ──────────────────────────────────────
            Center(
              child: Column(children: [
                Stack(
                  children: [
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: user?.avatarUrl.isNotEmpty == true
                              ? null
                              : AppStyles.primaryGradient,
                          image: user?.avatarUrl.isNotEmpty == true
                              ? DecorationImage(
                                  image: NetworkImage(user!.avatarUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: user?.avatarUrl.isNotEmpty != true
                            ? Icon(
                                isAdmin
                                    ? Icons.admin_panel_settings_rounded
                                    : Icons.person_rounded,
                                color: Colors.white,
                                size: 44)
                            : null,
                      ),
                    ),
                    if (_uploadingAvatar)
                      const Positioned.fill(
                        child:
                            CircularProgressIndicator(color: AppStyles.primary),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppStyles.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(auth.username,
                    style: TextStyle(
                        color: AppStyles.adaptiveTextPrimary(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppStyles.adaptivePrimaryBg(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(roleLabel,
                      style: const TextStyle(
                          color: AppStyles.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            const SizedBox(height: 24),

            // ─── Статистика ──────────────────────────────────────────────────
            if (!isAdmin) _buildStatsCard(),
            if (!isAdmin) const SizedBox(height: 24),

            // ─── История моек ────────────────────────────────────────────────
            if (!isAdmin) _buildHistorySection(),
            if (!isAdmin) const SizedBox(height: 24),

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
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 10),
                child: Text('Будут автоматически заполняться при записи',
                    style: TextStyle(
                        color: AppStyles.adaptiveTextSecondary(context),
                        fontSize: 12)),
              ),
              TextFormField(
                controller: _carModelCtrl,
                style: TextStyle(color: AppStyles.adaptiveTextPrimary(context)),
                decoration: AppStyles.inputDecorationFor(
                    context, 'Марка и модель авто',
                    hint: 'Toyota Camry', icon: Icons.directions_car_outlined),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _carNumberCtrl,
                style: TextStyle(
                    color: AppStyles.adaptiveTextPrimary(context),
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
                validator: _changePass
                    ? (v) =>
                        (v == null || v.length < 4) ? 'Минимум 4 символа' : null
                    : null,
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

  Widget _buildStatsCard() {
    if (_statsLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppStyles.primary));
    }
    final stats = _stats;
    if (stats == null) return const SizedBox.shrink();

    final isWasher = context.read<AuthProvider>().isWasher;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppStyles.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(stats.level,
                  style: const TextStyle(
                      color: AppStyles.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            const Icon(Icons.local_car_wash,
                size: 16, color: AppStyles.primary),
            const SizedBox(width: 4),
            Text('${stats.totalAppointments} ${isWasher ? 'помыто' : 'моек'}',
                style: TextStyle(
                    color: AppStyles.adaptiveTextPrimary(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: stats.levelProgress / 100,
            backgroundColor: AppStyles.adaptiveBorder(context),
            color: AppStyles.primary,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 6),
          Text('${stats.levelProgress}% до следующего уровня',
              style: TextStyle(
                  color: AppStyles.adaptiveTextSecondary(context),
                  fontSize: 11)),
          const SizedBox(height: 16),
          Row(children: [
            _statItem('${stats.totalAppointments}',
                isWasher ? 'Помыто авто' : 'Моек'),
            if (!isWasher) ...[
              Container(
                  width: 1,
                  height: 32,
                  color: AppStyles.adaptiveBorder(context)),
              _statItem(
                  stats.favoriteWashType == '-' ? '—' : stats.favoriteWashType,
                  'Любимая мойка'),
            ],
          ]),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.adaptiveTextPrimary(context))),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: AppStyles.adaptiveTextSecondary(context))),
        ]),
      );

  Widget _buildHistorySection() {
    if (_historyLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppStyles.primary));
    }
    final items = _history.take(5).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('История моек'),
        const SizedBox(height: 10),
        ...items.map((a) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: AppStyles.cardDecorationFor(context),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppStyles.adaptivePrimaryBg(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.local_car_wash,
                      color: AppStyles.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${DateFormat('d MMM', 'ru').format(a.dateTime)} · ${DateFormat('HH:mm').format(a.dateTime)}',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppStyles.adaptiveTextSecondary(context))),
                      const SizedBox(height: 2),
                      Text(a.carModel,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.adaptiveTextPrimary(context))),
                    ],
                  ),
                ),
                Text('${a.paidPrice} ₽',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.primary)),
              ]),
            )),
      ],
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
    return SegmentedButton<AppThemeMode>(
      segments: const [
        ButtonSegment(
          value: AppThemeMode.system,
          label: Text('Системная', style: TextStyle(fontSize: 12)),
          icon: Icon(Icons.settings_brightness, size: 18),
        ),
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
      selected: {themeProvider.appThemeMode},
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

  InputDecoration _plateDecoration() {
    final base = AppStyles.inputDecorationFor(context, 'Гос. номер',
        icon: Icons.pin_outlined);
    return base.copyWith(
      helperText: 'Формат: А000АА777',
      helperStyle: TextStyle(
          color: AppStyles.adaptiveTextSecondary(context), fontSize: 11),
    );
  }
}
