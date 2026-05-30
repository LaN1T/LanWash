import 'dart:async'; // Add this
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/service.dart';
import '../../services/notification_service.dart'; // Add this
import '../shared/profile_screen.dart';
import '../shared/shift_schedule_screen.dart';
import '../admin/notes_screen.dart';
import '../shared/appointment_detail_widget.dart';

class WasherShell extends StatefulWidget {
  const WasherShell({super.key});
  @override
  State<WasherShell> createState() => _WasherShellState();
}

class _WasherShellState extends State<WasherShell> {
  int _tabIndex = 0;
  DateTime _selectedDay = DateTime.now();
  StreamSubscription? _appointmentSub; // подписка на обновления записей

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<AppProvider>().loadNotes(username: auth.userLogin);
      context.read<AppProvider>().reloadAppointments(auth);

      // Listen for updates
      _appointmentSub = NotificationService().onAppointmentUpdated.listen((id) {
        if (mounted) {
          context.read<AppProvider>().reloadAppointments(auth);
        }
      });
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

    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppStyles.textPrimary,
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
          Text(_tabIndex == 0 ? 'Мои записи' : 'Мои заметки',
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.textPrimary)),
        ]),
      ),
      drawer: _buildDrawer(context, auth),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildAppointmentsTab(),
          const NotesScreen(isEmbedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_today), label: 'Записи'),
          NavigationDestination(icon: Icon(Icons.note_alt), label: 'Заметки'),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    final provider = context.watch<AppProvider>();
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
                final today = DateTime.now();
                final currentWeekStart =
                    today.subtract(Duration(days: today.weekday - 1));
                final newWeekStart = currentWeekStart
                    .add(Duration(days: (pageIndex - 500000) * 7));
                setState(() {
                  _selectedDay = newWeekStart
                      .add(Duration(days: _selectedDay.weekday - 1));
                });
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
                              color:
                                  isSelected ? AppStyles.primary : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: isSelected
                                      ? AppStyles.primary
                                      : (isToday
                                          ? AppStyles.primary
                                          : Colors.grey.shade200),
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
                                            : AppStyles.textSecondary,
                                        fontSize: 9)),
                                Text('${d.day}',
                                    style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : AppStyles.textPrimary,
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
                            color:
                                AppStyles.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text('На выбранный день записей нет',
                            style: AppStyles.headingMedium
                                .copyWith(color: AppStyles.textSecondary)),
                        const SizedBox(height: 6),
                        const Text('Выберите другой день или проверьте фильтры',
                            style: AppStyles.bodyMedium),
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
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            color: Colors.white,
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
              const Text('LanWash',
                  style: TextStyle(
                      color: AppStyles.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppStyles.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppStyles.warning.withValues(alpha: 0.2)),
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
          const Divider(color: AppStyles.border, height: 1),
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
                      : AppStyles.textSecondary,
                  size: 22),
              title: Text('Мои записи',
                  style: TextStyle(
                      color: _tabIndex == 0
                          ? AppStyles.primary
                          : AppStyles.textPrimary,
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
                      : AppStyles.textSecondary,
                  size: 22),
              title: Text('Мои заметки',
                  style: TextStyle(
                      color: _tabIndex == 1
                          ? AppStyles.primary
                          : AppStyles.textPrimary,
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
          const Divider(color: AppStyles.border, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: const Icon(Icons.schedule_outlined,
                  color: AppStyles.textSecondary, size: 22),
              title: const Text('Сменное расписание',
                  style: TextStyle(color: AppStyles.textPrimary)),
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
              leading: const Icon(Icons.person_outline_rounded,
                  color: AppStyles.textSecondary, size: 22),
              title: const Text('Профиль',
                  style: TextStyle(color: AppStyles.textPrimary)),
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
              leading: const Icon(Icons.logout_outlined,
                  color: AppStyles.textSecondary, size: 22),
              title: const Text('Выйти',
                  style: TextStyle(color: AppStyles.textSecondary)),
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

  void _confirmLogout(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы вернётесь на экран входа.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
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

class _WasherAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  const _WasherAppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final statusColor = AppStyles.statusColor(a.status);
    final provider = context.watch<AppProvider>();
    final washType = provider.washTypeById(a.washTypeId);
    final extras = a.additionalServices
        .where((id) => !(washType?.includedExtraIds.contains(id) ?? false));
    final duration = (washType?.durationMinutes ?? 30) +
        extras.fold(
            0,
            (sum, id) =>
                sum +
                (provider.services
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
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppStyles.border)),
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
                      color: AppStyles.primaryBg,
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
                const Icon(Icons.person,
                    size: 16, color: AppStyles.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(a.clientName,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.directions_car,
                    size: 16, color: AppStyles.textSecondary),
                const SizedBox(width: 6),
                Text(a.carModel,
                    style: const TextStyle(
                        fontSize: 13, color: AppStyles.textSecondary)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppStyles.primaryBg,
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
