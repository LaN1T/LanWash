import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/note_provider.dart';
import '../shared/profile_screen.dart';
import 'appointments_screen.dart';
import 'services_screen.dart';
import 'favorites_screen.dart';
import 'add_edit_appointment_screen.dart';
import 'add_edit_service_screen.dart';
import 'logs_screen.dart';
import 'notes_screen.dart';
import 'reports_shell_screen.dart'; // Импорт для отчетов
import 'wash_type_settings_screen.dart';
import '../shared/shift_schedule_screen.dart';
import '../shared/statistics_screen.dart';
import 'consumables_stock_screen.dart';
import 'reviews_moderation_screen.dart';
import 'admin_dashboard_screen.dart';
import 'client_search_screen.dart';
import 'inventory_forecast_screen.dart';
import 'support_tickets_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _titles = ['Записи на мойку', 'Услуги', 'Избранное'];

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final theme = Theme.of(context);
    if (appointmentProvider.loading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.local_car_wash, color: AppStyles.primary, size: 72),
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

    // У админа считаем только избранные ЗАПИСИ (не услуги клиента)
    final favCount = appointmentProvider.favoriteAppointments.length;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppStyles.primaryGradient,
            ),
            child:
                const Icon(Icons.local_car_wash, color: Colors.white, size: 18),
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
        actions: _index == 2
            ? null
            : [
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
      drawer: _buildDrawer(context, favCount),
      body: IndexedStack(
        index: _index,
        children: const [
          AppointmentsScreen(),
          ServicesScreen(),
          FavoritesScreen(),
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
            NavigationDestination(
              icon: Badge(
                isLabelVisible: favCount > 0,
                label: Text('$favCount'),
                backgroundColor: AppStyles.primary,
                child: Icon(Icons.star_outline,
                    color: AppStyles.adaptiveTextSecondary(context)),
              ),
              selectedIcon: const Icon(Icons.star, color: AppStyles.primary),
              label: 'Избранное',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext ctx, int favCount) {
    final auth = ctx.watch<AuthProvider>();
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppStyles.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppStyles.primary.withValues(alpha: 0.3),
                      blurRadius: 20,
                    )
                  ],
                ),
                child: const Icon(Icons.local_car_wash,
                    color: Colors.white, size: 32),
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
                child: Text(auth.username,
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
          _drawerItem(ctx, 2, Icons.star_outline, Icons.star, 'Избранное',
              favCount > 0 ? '$favCount' : null),
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
              leading: Badge(
                isLabelVisible: context.watch<NoteProvider>().unreadNotes > 0,
                label: Text('${context.watch<NoteProvider>().unreadNotes}'),
                backgroundColor: AppStyles.danger,
                child: Icon(Icons.note_alt_outlined,
                    color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
              ),
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
          if (auth.isAdmin)
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
          if (auth.isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: Badge(
                  isLabelVisible: context.watch<SupportProvider>().unreadAdminCount > 0,
                  label: Text('${context.watch<SupportProvider>().unreadAdminCount}'),
                  backgroundColor: AppStyles.danger,
                  child: Icon(Icons.support_agent,
                      color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
                ),
                title: Text('Поддержка',
                    style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
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
          // Дашборд
          if (auth.isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: Icon(Icons.dashboard_rounded,
                    color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
                title: Text('Дашборд',
                    style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const AdminDashboardScreen()));
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          // Прогноз расходников
          if (auth.isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: Icon(Icons.inventory_2_outlined,
                    color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
                title: Text('Расходники',
                    style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const InventoryForecastScreen()));
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          // Поиск клиентов
          if (auth.isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: Icon(Icons.people_alt_outlined,
                    color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
                title: Text('Клиенты',
                    style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
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
          // Отчёты
          if (auth.isAdmin)
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
          // Управление запасами
          if (auth.isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: Icon(Icons.inventory_2_outlined,
                    color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
                title: Text('Управление запасами',
                    style:
                        TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const ConsumablesStockScreen()));
                },
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          // Настройки
          if (auth.isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: ListTile(
                minLeadingWidth: 24,
                leading: Icon(Icons.settings_rounded,
                    color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
                title: Text('Настройки',
                    style:
                        TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => const WashTypeSettingsScreen()));
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: Icon(Icons.logout_outlined,
                  color: AppStyles.adaptiveTextSecondary(ctx), size: 22),
              title: Text('Сменить профиль',
                  style:
                      TextStyle(color: AppStyles.adaptiveTextSecondary(ctx))),
              onTap: () {
                Navigator.pop(ctx);
                ctx.read<AuthProvider>().logout();
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
