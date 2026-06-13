import 'dart:async'; // Add this
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../models/tip.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/note_provider.dart';
import '../../models/service.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/offline_status_indicator.dart';
import '../shared/profile_screen.dart';
import '../shared/shift_schedule_screen.dart';
import '../shared/statistics_screen.dart';
import '../admin/notes_screen.dart';
import '../shared/appointment_detail_widget.dart';
import 'qr_scanner_screen.dart';

class WasherShell extends StatefulWidget {
  const WasherShell({super.key});
  @override
  State<WasherShell> createState() => _WasherShellState();
}

class _WasherShellState extends State<WasherShell> {
  int _tabIndex = 0;
  DateTime _selectedDay = DateTime.now();
  StreamSubscription? _appointmentSub;
  List<dynamic> _tips = [];
  bool _tipsLoading = false;
  dynamic _tipStats;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<NoteProvider>().loadNotes(username: auth.userLogin);
      context.read<AppointmentProvider>().reloadAppointments(auth);
    });

    _appointmentSub = NotificationService().onAppointmentUpdated.listen((id) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      context.read<AppointmentProvider>().reloadAppointments(auth);
    });
  }

  @override
  void dispose() {
    _appointmentSub?.cancel(); // Cancel subscription
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Row(children: [
          Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, gradient: AppStyles.primaryGradient),
              child: const Icon(Icons.local_car_wash,
                  color: Colors.white, size: 18)),
          const SizedBox(width: 10),
          Text(
            _tabIndex == 0
                ? 'Мои записи'
                : _tabIndex == 1
                    ? 'Мои заметки'
                    : 'Чаевые',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
        ]),
        actions: [
          const OfflineStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppStyles.primary),
            tooltip: 'Сканировать QR',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerScreen()),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, auth),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildAppointmentsTab(),
          const NotesScreen(isEmbedded: true),
          _buildTipsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          setState(() => _tabIndex = i);
          if (i == 2) _loadTips();
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_today), label: 'Записи'),
          NavigationDestination(icon: Icon(Icons.note_alt), label: 'Заметки'),
          NavigationDestination(
              icon: Icon(Icons.volunteer_activism), label: 'Чаевые'),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    final provider = context.watch<AppointmentProvider>();
    final auth = context.read<AuthProvider>();
    final appts = provider.appointments;

    if (provider.loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppStyles.primary));
    }

    final filteredAppts = appts
        .where((a) =>
            a.dateTime.year == _selectedDay.year &&
            a.dateTime.month == _selectedDay.month &&
            a.dateTime.day == _selectedDay.day)
        .toList();

    return RefreshIndicator(
      color: AppStyles.primary,
      onRefresh: () => provider.reloadAppointments(auth),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            height: 80,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: PageView.builder(
              controller: PageController(initialPage: 500000),
              itemCount: 1000000,
              onPageChanged: (pageIndex) {
                // Неделя перелистнута, но выбранный день НЕ меняется автоматически
              },
              itemBuilder: (ctx, pageIndex) {
                final today = DateTime.now();
                final currentWeekStart =
                    today.subtract(Duration(days: today.weekday - 1));
                final startOfWeek = currentWeekStart
                    .add(Duration(days: (pageIndex - 500000) * 7));
                return Row(
                  children: List.generate(7, (i) {
                    final d = startOfWeek.add(Duration(days: i));
                    final count = appts
                        .where((a) =>
                            a.dateTime.year == d.year &&
                            a.dateTime.month == d.month &&
                            a.dateTime.day == d.day)
                        .length;
                    final isSelected = d.day == _selectedDay.day &&
                        d.month == _selectedDay.month &&
                        d.year == _selectedDay.year;
                    final isToday = d.day == DateTime.now().day &&
                        d.month == DateTime.now().month &&
                        d.year == _selectedDay.year;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedDay = d),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 2, vertical: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppStyles.primary
                                  : AppStyles.adaptiveCard(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isSelected
                                      ? AppStyles.primary
                                      : (isToday
                                          ? AppStyles.primary
                                          : AppStyles.adaptiveBorder(context)),
                                  width: isToday ? 2 : 1),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                    DateFormat('E', 'ru')
                                        .format(d)
                                        .toUpperCase(),
                                    style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppStyles.adaptiveTextSecondary(
                                                context),
                                        fontSize: 9)),
                                Text('${d.day}',
                                    style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppStyles.adaptiveTextPrimary(
                                                context),
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold)),
                                if (count > 0)
                                  Container(
                                    width: 14,
                                    height: 14,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : AppStyles.primary,
                                        shape: BoxShape.circle),
                                    child: Text('$count',
                                        style: TextStyle(
                                            color: isSelected
                                                ? AppStyles.primary
                                                : Colors.white,
                                            fontSize: 8,
                                            fontWeight: FontWeight.bold)),
                                  )
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height - 250,
            child: filteredAppts.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_note_outlined,
                            size: 64,
                            color: AppStyles.adaptiveTextSecondary(context)
                                .withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text('На выбранный день записей нет',
                            style: AppStyles.headingMedium.copyWith(
                                color:
                                    AppStyles.adaptiveTextSecondary(context))),
                        const SizedBox(height: 6),
                        Text('Выберите другой день или проверьте фильтры',
                            style: AppStyles.bodyMedium.copyWith(
                                color:
                                    AppStyles.adaptiveTextSecondary(context))),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredAppts.length,
                    itemBuilder: (context, index) {
                      return _WasherAppointmentCard(
                          appointment: filteredAppts[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext ctx, AuthProvider auth) {
    final dark = AppStyles.isDark(ctx);
    return Drawer(
      backgroundColor: AppStyles.adaptiveCard(ctx),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            color: AppStyles.adaptiveCard(ctx),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppStyles.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppStyles.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                    )
                  ],
                ),
                child: const Icon(Icons.local_car_wash,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(height: 14),
              Text('LanWash',
                  style: TextStyle(
                      color: AppStyles.adaptiveTextPrimary(ctx),
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppStyles.warning.withValues(alpha: dark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppStyles.warning
                          .withValues(alpha: dark ? 0.3 : 0.2)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.person_rounded,
                      size: 12, color: AppStyles.warning),
                  const SizedBox(width: 4),
                  Text(auth.username,
                      style: const TextStyle(
                          color: AppStyles.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          Divider(color: AppStyles.adaptiveBorder(ctx), height: 1),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(
                  _tabIndex == 0
                      ? Icons.calendar_today
                      : Icons.calendar_today_outlined,
                  color: _tabIndex == 0
                      ? AppStyles.primary
                      : AppStyles.adaptiveTextSecondary(ctx),
                  size: 22),
              title: Text('Мои записи',
                  style: TextStyle(
                      color: _tabIndex == 0
                          ? AppStyles.primary
                          : AppStyles.adaptiveTextPrimary(ctx),
                      fontWeight: _tabIndex == 0
                          ? FontWeight.w600
                          : FontWeight.normal)),
              selected: _tabIndex == 0,
              selectedTileColor: AppStyles.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () {
                setState(() => _tabIndex = 0);
                Navigator.pop(ctx);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(
                  _tabIndex == 1
                      ? Icons.note_alt_rounded
                      : Icons.note_alt_outlined,
                  color: _tabIndex == 1
                      ? AppStyles.primary
                      : AppStyles.adaptiveTextSecondary(ctx),
                  size: 22),
              title: Text('Мои заметки',
                  style: TextStyle(
                      color: _tabIndex == 1
                          ? AppStyles.primary
                          : AppStyles.adaptiveTextPrimary(ctx),
                      fontWeight: _tabIndex == 1
                          ? FontWeight.w600
                          : FontWeight.normal)),
              selected: _tabIndex == 1,
              selectedTileColor: AppStyles.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () {
                setState(() => _tabIndex = 1);
                Navigator.pop(ctx);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(
                  _tabIndex == 2
                      ? Icons.volunteer_activism
                      : Icons.volunteer_activism_outlined,
                  color: _tabIndex == 2
                      ? AppStyles.primary
                      : AppStyles.adaptiveTextSecondary(ctx),
                  size: 22),
              title: Text('Чаевые',
                  style: TextStyle(
                      color: _tabIndex == 2
                          ? AppStyles.primary
                          : AppStyles.adaptiveTextPrimary(ctx),
                      fontWeight: _tabIndex == 2
                          ? FontWeight.w600
                          : FontWeight.normal)),
              selected: _tabIndex == 2,
              selectedTileColor: AppStyles.primary.withValues(alpha: 0.08),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              onTap: () {
                setState(() => _tabIndex = 2);
                _loadTips();
                Navigator.pop(ctx);
              },
            ),
          ),
          Divider(
              color: AppStyles.adaptiveBorder(ctx), indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(Icons.schedule_outlined,
                  color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
              title: Text('Расписание',
                  style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => const ShiftScheduleScreen()));
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(Icons.bar_chart_rounded,
                  color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
              title: Text('Статистика',
                  style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => const StatisticsScreen()));
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(Icons.person_outline_rounded,
                  color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
              title: Text('Профиль',
                  style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(Icons.logout_outlined,
                  color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
              title: Text('Выйти',
                  style:
                      TextStyle(color: AppStyles.adaptiveTextSecondary(ctx))),
              onTap: () {
                Navigator.pop(ctx);
                _confirmLogout(ctx);
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _loadTips() async {
    setState(() => _tipsLoading = true);
    final api = context.read<ApiService>();
    final tips = await api.getMyTips();
    final stats = await api.getTipStats();
    if (mounted) {
      setState(() {
        _tips = tips;
        _tipStats = stats;
        _tipsLoading = false;
      });
    }
  }

  Widget _buildTipsTab() {
    if (_tipsLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppStyles.primary));
    }
    final stats = _tipStats as TipStats?;
    return RefreshIndicator(
      color: AppStyles.primary,
      onRefresh: _loadTips,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (stats != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.adaptiveCard(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppStyles.adaptiveBorder(context)),
              ),
              child: Row(
                children: [
                  _StatItem('Всего', stats.totalTips.toString()),
                  const VerticalDivider(),
                  _StatItem('Получено', '${stats.totalAmount} ₽'),
                  const VerticalDivider(),
                  _StatItem('Ожидает', '${stats.pendingAmount} ₽'),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_tips.isEmpty)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 40),
                  Icon(Icons.volunteer_activism,
                      size: 56,
                      color: AppStyles.adaptiveTextSecondary(context)
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('Пока нет чаевых',
                      style: AppStyles.headingMedium.copyWith(
                          color: AppStyles.adaptiveTextSecondary(context))),
                ],
              ),
            )
          else
            ..._tips.map((t) => _TipCard(tip: t as Tip, onRefresh: _loadTips)),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Выйти из аккаунта?',
            style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
        content: Text('Вы вернётесь на экран входа.',
            style: TextStyle(color: AppStyles.adaptiveTextSecondary(ctx))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Отмена',
                  style:
                      TextStyle(color: AppStyles.adaptiveTextSecondary(ctx)))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () {
              Navigator.pop(ctx);
              ctx.read<AuthProvider>().logout();
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.primary)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppStyles.adaptiveTextSecondary(context))),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final Tip tip;
  final VoidCallback onRefresh;
  const _TipCard({required this.tip, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isPending = tip.status == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppStyles.adaptiveCard(context),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppStyles.adaptiveBorder(context))),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isPending
                        ? AppStyles.warning.withValues(alpha: 0.1)
                        : AppStyles.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(tip.statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            isPending ? AppStyles.warning : AppStyles.success)),
              ),
              const Spacer(),
              Text('${tip.amount} ₽',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.primary)),
            ]),
            const SizedBox(height: 10),
            Text('Способ: ${tip.methodLabel}',
                style: TextStyle(
                    fontSize: 13,
                    color: AppStyles.adaptiveTextSecondary(context))),
            const SizedBox(height: 4),
            Text('Запись: ${tip.appointmentId}',
                style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.adaptiveTextSecondary(context))),
            if (isPending && tip.method != 'sbp') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final scaffold = ScaffoldMessenger.of(context);
                    final ok =
                        await context.read<ApiService>().markTipPaid(tip.id);
                    if (ok) {
                      onRefresh();
                    } else {
                      scaffold.showSnackBar(
                        const SnackBar(
                            content: Text('Не удалось отметить'),
                            backgroundColor: AppStyles.danger),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Отметить получено'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppStyles.success,
                    side: const BorderSide(color: AppStyles.success),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WasherAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  const _WasherAppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final statusColor = AppStyles.statusColor(a.status);
    final catalogProvider = context.watch<CatalogProvider>();
    final washType = catalogProvider.washTypeById(a.washTypeId);
    final extras = a.additionalServices
        .where((id) => !(washType?.includedExtraIds.contains(id) ?? false));
    final duration = (washType?.durationMinutes ?? 30) +
        extras.fold(
            0,
            (sum, id) =>
                sum +
                (catalogProvider.services
                    .firstWhere((s) => s.id == id,
                        orElse: () => Service(
                            id: id,
                            name: id,
                            description: '',
                            price: 0,
                            durationMinutes: 0,
                            category: ''))
                    .durationMinutes));
    final endTime = a.dateTime.add(Duration(minutes: duration.toInt()));
    final cutoff =
        DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day, 22, 0);
    String timeStr;
    if (endTime.isAfter(cutoff)) {
      final overflow = endTime.difference(cutoff).inMinutes;
      timeStr =
          '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — 22:00, ⚠ Завтра до ${((8 * 60 + overflow) ~/ 60).toString().padLeft(2, '0')}:${((8 * 60 + overflow) % 60).toString().padLeft(2, '0')}';
    } else {
      timeStr =
          '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — ${DateFormat('HH:mm', 'ru').format(endTime)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppStyles.adaptiveCard(context),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppStyles.adaptiveBorder(context))),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) =>
              AppointmentDetailWidget(appointment: a, isClient: false),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    Icon(AppStyles.statusIcon(a.status),
                        size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(AppStyles.statusLabel(a.status),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ]),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppStyles.adaptivePrimaryBg(context),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(timeStr,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primary)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.person,
                    size: 16, color: AppStyles.adaptiveTextSecondary(context)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(a.clientName,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppStyles.adaptiveTextPrimary(context)))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.directions_car,
                    size: 16, color: AppStyles.adaptiveTextSecondary(context)),
                const SizedBox(width: 6),
                Text(a.carModel,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.adaptiveTextSecondary(context))),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppStyles.adaptivePrimaryBg(context),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('Бокс №${a.box_index + 1}',
                      style: const TextStyle(
                          color: AppStyles.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
