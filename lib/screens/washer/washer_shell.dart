import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import '../admin/notes_screen.dart';
import '../shared/splash_screen.dart' show LanWashLogo;
import 'qr_scanner_screen.dart';
import 'washer_appointments_screen.dart';
import 'washer_dashboard_screen.dart';
import 'washer_history_screen.dart';
import 'washer_tips_screen.dart';

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
          WasherAppointmentsScreen(),
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
            color: selected
                ? AppStyles.primary
                : AppStyles.adaptiveTextSecondary(ctx),
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                      await context
                          .read<AppointmentProvider>()
                          .reloadAppointments(auth);
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
                  icon: Icons.work_outline_rounded,
                  title: 'Мой день',
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const WasherDashboardScreen()),
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
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
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
