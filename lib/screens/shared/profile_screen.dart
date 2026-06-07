import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../app_styles.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../models/appointment.dart';
import '../../models/user_stats.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _uploadingAvatar = false;

  UserStats? _stats;
  bool _statsLoading = true;
  List<Appointment> _history = [];
  bool _historyLoading = true;

  @override
  void initState() {
    super.initState();
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
    const maxAvatarSizeBytes = 5 * 1024 * 1024; // 5 MB
    final fileSize =
        result.files.single.size > 0 ? result.files.single.size : bytes.length;
    if (fileSize > maxAvatarSizeBytes) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл слишком большой. Максимум 5 МБ.')),
        );
      }
      return;
    }

    final filename = result.files.single.name;
    final user = auth.user;
    if (user?.id == null) return;

    setState(() => _uploadingAvatar = true);
    final url = await api.uploadAvatar(user!.id!, bytes, filename);
    if (!mounted) return;
    setState(() => _uploadingAvatar = false);

    if (url != null) {
      await auth.updateAvatar(url);
      _showSnack('Аватар обновлён');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppStyles.danger : AppStyles.success,
    ));
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
      body: ListView(
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
                                image:
                                    CachedNetworkImageProvider(user!.avatarUrl),
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

          // ─── Данные профиля (только просмотр) ────────────────────────────
          _sectionLabel('Основные данные'),
          const SizedBox(height: 10),
          _infoTile(
              Icons.person_outline_rounded, 'Имя', user?.displayName ?? '—'),
          _infoTile(
              Icons.alternate_email_rounded, 'Логин', user?.username ?? '—'),
          _infoTile(Icons.phone_outlined, 'Телефон',
              (user?.phone ?? '').isEmpty ? '—' : user!.phone),
          const SizedBox(height: 24),

          if (!isAdmin) ...[
            _sectionLabel('Данные автомобиля'),
            const SizedBox(height: 10),
            _infoTile(Icons.directions_car_outlined, 'Марка и модель',
                (user?.carModel ?? '').isEmpty ? '—' : user!.carModel),
            _infoTile(Icons.pin_outlined, 'Гос. номер',
                (user?.carNumber ?? '').isEmpty ? '—' : user!.carNumber),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppStyles.cardDecorationFor(context),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppStyles.adaptiveTextSecondary(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: AppStyles.adaptiveTextSecondary(context),
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.adaptiveTextPrimary(context))),
              ],
            ),
          ),
        ],
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
}
