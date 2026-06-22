import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/offline_status_indicator.dart';
import '../client/booking_wizard_screen.dart';
import '../client/support_chats_screen.dart';
import '../shared/profile_screen.dart';
import '../client/settings_screen.dart';
import '../shared/shift_schedule_screen.dart';
import '../shared/statistics_screen.dart';
import '../admin/notes_screen.dart';
import '../shared/splash_screen.dart';
import 'qr_scanner_screen.dart';
import 'washer_history_screen.dart';
import 'washer_tips_screen.dart';
import '../../widgets/washer/washer_appointment_card.dart';

class WasherShell extends StatefulWidget {
  const WasherShell({super.key});
  @override
  State<WasherShell> createState() => _WasherShellState();
}

class _WasherShellState extends State<WasherShell> {
  int _tabIndex = 0;
  StreamSubscription? _appointmentSub;

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
    _appointmentSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Row(children: [
          const LanWashLogo(
            circleSize: 34,
            showTitle: false,
            showSubtitle: false,
            showLoader: false,
            shadowBlur: null,
          ),
          const SizedBox(width: 10),
          Text(
            _tabIndex == 0 ? 'Мои записи' : 'Мои заметки',
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
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _tabIndex,
        children: const [
          _WasherAppointmentsTab(),
          NotesScreen(isEmbedded: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) {
          setState(() => _tabIndex = i);
        },
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.calendar_today), label: 'Записи'),
          NavigationDestination(icon: Icon(Icons.note_alt), label: 'Заметки'),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext ctx) {
    final username = ctx.select<AuthProvider, String>((a) => a.username);
    final dark = AppStyles.isDark(ctx);

    Widget section(String title) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              color: AppStyles.adaptiveTextMuted(ctx),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
        );

    Widget tile({
      required IconData icon,
      required String title,
      bool selected = false,
      VoidCallback? onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: ListTile(
          minLeadingWidth: 24,
          leading: Icon(
            icon,
            color: selected ? AppStyles.primary : AppStyles.adaptiveTextSecondary(ctx),
            size: 22,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: selected
                  ? AppStyles.primary
                  : AppStyles.adaptiveTextPrimary(ctx),
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          selected: selected,
          selectedTileColor: AppStyles.primary.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          onTap: onTap,
        ),
      );
    }

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
              const LanWashLogo(
                circleSize: 56,
                showTitle: false,
                showSubtitle: false,
                showLoader: false,
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
                  Text(username,
                      style: const TextStyle(
                          color: AppStyles.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ]),
              ),
            ]),
          ),
          Divider(color: AppStyles.adaptiveBorder(ctx), height: 1),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                section('Записи'),
                tile(
                  icon: _tabIndex == 0
                      ? Icons.calendar_today
                      : Icons.calendar_today_outlined,
                  title: 'Мои записи',
                  selected: _tabIndex == 0,
                  onTap: () {
                    setState(() => _tabIndex = 0);
                    Navigator.pop(ctx);
                  },
                ),
                tile(
                  icon: Icons.history_rounded,
                  title: 'История',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const WasherHistoryScreen()),
                    );
                  },
                ),
                tile(
                  icon: Icons.add_circle_outline_rounded,
                  title: 'Записаться на мойку',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const BookingWizardScreen()),
                    );
                    if (mounted) {
                      final auth = context.read<AuthProvider>();
                      await context.read<AppointmentProvider>().reloadAppointments(auth);
                    }
                  },
                ),
                section('Работа'),
                tile(
                  icon: Icons.schedule_outlined,
                  title: 'Расписание',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const ShiftScheduleScreen()),
                    );
                  },
                ),
                tile(
                  icon: Icons.event_available_outlined,
                  title: 'Доступность',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                        builder: (_) => const ShiftScheduleScreen(
                            initialMode: ShiftScheduleMode.availability),
                      ),
                    );
                  },
                ),
                tile(
                  icon: Icons.bar_chart_rounded,
                  title: 'Статистика',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const StatisticsScreen()),
                    );
                  },
                ),
                tile(
                  icon: Icons.volunteer_activism_outlined,
                  title: 'Чаевые',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const WasherTipsScreen()),
                    );
                  },
                ),
                section('Поддержка'),
                tile(
                  icon: Icons.support_agent_outlined,
                  title: 'Написать в поддержку',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const SupportChatsScreen()),
                    );
                  },
                ),
                section('Аккаунт'),
                tile(
                  icon: Icons.person_outline_rounded,
                  title: 'Профиль',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const ProfileScreen()),
                    );
                  },
                ),
                tile(
                  icon: Icons.settings_outlined,
                  title: 'Настройки',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const SettingsScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _WasherAppointmentsTab extends StatefulWidget {
  const _WasherAppointmentsTab();

  @override
  State<_WasherAppointmentsTab> createState() => _WasherAppointmentsTabState();
}

class _WasherAppointmentsTabState extends State<_WasherAppointmentsTab> {
  DateTime _selectedDay = DateTime.now();
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 500000);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<AppointmentProvider>().reloadAppointments(auth);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              controller: _pageController,
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
                      return WasherAppointmentCard(
                          appointment: filteredAppts[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
