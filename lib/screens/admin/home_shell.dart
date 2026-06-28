import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consumable_provider.dart';
import '../../providers/note_provider.dart';
import '../../providers/support_provider.dart';
import '../../widgets/offline_status_indicator.dart';
import '../shared/profile_screen.dart';
import '../shared/splash_screen.dart';
import 'appointments_screen.dart';
import 'services_screen.dart';
import 'favorites_screen.dart';
import 'add_edit_appointment_screen.dart';
import 'add_edit_service_screen.dart';
import 'logs_screen.dart';
import 'notes_screen.dart';
import 'reports_shell_screen.dart'; // Импорт для отчетов
import 'admin_settings_shell_screen.dart';
import 'admin_statistics_shell_screen.dart';
import '../shared/shift_schedule_screen.dart';
import 'reviews_moderation_screen.dart';
import 'client_search_screen.dart';
import 'support_tickets_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _titles = ['Записи на мойку', 'Услуги'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConsumableProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final loading = appointmentProvider.loading;
    final theme = Theme.of(context);
    if (loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const LanWashLogo(
            circleSize: 72,
            showTitle: false,
            showSubtitle: false,
            showLoader: false,
            shadowBlur: null,
          ),
          const SizedBox(height: 20),
          Text('LanWash',
              style: TextStyle(
                  color: AppStyles.adaptiveTextPrimary(context),
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          const CircularProgressIndicator(color: AppStyles.primary),
        ])),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Row(children: [
          const LanWashLogo(
            circleSize: 32,
            showTitle: false,
            showSubtitle: false,
            showLoader: false,
            shadowBlur: null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_titles[_index],
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          ),
        ]),
        // Кнопка выхода убрана из appBar — только в drawer
        actions: [
          const OfflineStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.add, color: AppStyles.primary),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _index == 0
                    ? const AddEditAppointmentScreen()
                    : const AddEditServiceScreen(),
              ),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(context),
      body: IndexedStack(
        index: _index,
        children: const [
          AppointmentsScreen(),
          ServicesScreen(),
        ],
      ),
      floatingActionButton: null,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppStyles.adaptiveCard(context),
          border:
              Border(top: BorderSide(color: AppStyles.adaptiveBorder(context))),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppStyles.adaptivePrimaryBg(context),
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined,
                  color: AppStyles.adaptiveTextSecondary(context)),
              selectedIcon:
                  const Icon(Icons.calendar_today, color: AppStyles.primary),
              label: 'Записи',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_car_wash,
                  color: AppStyles.adaptiveTextSecondary(context)),
              selectedIcon:
                  const Icon(Icons.local_car_wash, color: AppStyles.primary),
              label: 'Услуги',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext ctx) {
    final username = ctx.select<AuthProvider, String>((a) => a.username);
    final isAdmin = ctx.select<AuthProvider, bool>((a) => a.isAdmin);
    final favCount = ctx.select<AppointmentProvider, int>(
        (ap) => ap.favoriteAppointments.length);
    return Drawer(
      backgroundColor: AppStyles.adaptiveCard(ctx),
      child: SafeArea(
        bottom: false,
        child: ListView(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            color: AppStyles.adaptiveCard(ctx),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const LanWashLogo(
                circleSize: 60,
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
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppStyles.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(username,
                    style: const TextStyle(
                        color: AppStyles.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          Divider(color: AppStyles.adaptiveBorder(ctx), height: 1),
          const SizedBox(height: 8),
          _drawerItem(ctx, 0, Icons.calendar_today_outlined,
              Icons.calendar_today, 'Записи на мойку', null),
          _drawerItem(ctx, 1, Icons.local_car_wash, Icons.local_car_wash,
              'Каталог услуг', null),
          // Избранное
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(Icons.star_outline,
                  color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
              title: Text('Избранное',
                  style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
              trailing: favCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppStyles.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$favCount',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()));
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          Divider(
              color: AppStyles.adaptiveBorder(ctx), indent: 16, endIndent: 16),
          // Сменное расписание
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
          // Заметки мойщиков
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: _NotesBadge(),
              title: Text('Заметки мойщиков',
                  style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => const NotesScreen()));
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          // Журнал действий
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(Icons.history_rounded,
                  color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
              title: Text('Журнал действий',
                  style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    ctx, MaterialPageRoute(builder: (_) => const LogsScreen()));
              },
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          // Модерация отзывов
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: Icon(Icons.reviews_outlined,
                    color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
                title: Text('Модерация отзывов',
                    style:
                        TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const ReviewsModerationScreen()));
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          // Поддержка
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: _SupportBadge(),
                title: Text('Поддержка',
                    style:
                        TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const SupportTicketsScreen()));
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          // Поиск клиентов
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: Icon(Icons.people_alt_outlined,
                    color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
                title: Text('Клиенты',
                    style:
                        TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const ClientSearchScreen()));
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          // Статистика
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: Icon(Icons.bar_chart_rounded,
                    color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
                title: Text('Статистика',
                    style:
                        TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const AdminStatisticsShellScreen()));
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          // Отчёты
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: Icon(Icons.show_chart_rounded,
                    color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
                title: Text('Отчёты',
                    style:
                        TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const ReportsShellScreen()));
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          // Настройки
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: const _SettingsBadge(),
                title: Text('Настройки',
                    style:
                        TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const AdminSettingsShellScreen()));
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          // Профиль
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
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _drawerItem(BuildContext ctx, int index, IconData icon,
      IconData selIcon, String label, String? badge) {
    final sel = _index == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        minLeadingWidth: 24,
        leading: Icon(sel ? selIcon : icon,
            size: 22,
            color:
                sel ? AppStyles.primary : AppStyles.adaptiveTextSecondary(ctx)),
        title: Text(label,
            style: TextStyle(
              color:
                  sel ? AppStyles.primary : AppStyles.adaptiveTextPrimary(ctx),
              fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
            )),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppStyles.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(badge,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
              )
            : null,
        selected: sel,
        selectedTileColor: AppStyles.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          setState(() => _index = index);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _NotesBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.watch<NoteProvider>().unreadNotes;

    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppStyles.danger,
      child: Icon(Icons.note_alt_outlined,
          color: AppStyles.adaptiveTextSecondary(context), size: 22),
    );
  }
}

class _SupportBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.watch<SupportProvider>().unreadAdminCount;

    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppStyles.danger,
      child: Icon(Icons.support_agent,
          color: AppStyles.adaptiveTextSecondary(context), size: 22),
    );
  }
}

class _SettingsBadge extends StatelessWidget {
  const _SettingsBadge();

  @override
  Widget build(BuildContext context) {
    final count = context.select<ConsumableProvider, int>((p) => p.lowStockCount);

    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppStyles.danger,
      child: Icon(Icons.settings_rounded,
          color: AppStyles.adaptiveTextSecondary(context), size: 22),
    );
  }
}
