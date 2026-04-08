import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_styles.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../screens/profile_screen.dart';
import 'appointments_screen.dart';
import 'services_screen.dart';
import 'favorites_screen.dart';
import 'add_edit_appointment_screen.dart';
import 'add_edit_service_screen.dart';
import 'logs_screen.dart';
import 'notes_screen.dart';
import 'admin_schedule_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  static const _titles = ['Записи на мойку', 'Услуги', 'Избранное'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (provider.loading) {
      return const Scaffold(
        backgroundColor: AppStyles.bgPage,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.local_car_wash, color: AppStyles.primary, size: 72),
          SizedBox(height: 20),
          Text('LanWash', style: TextStyle(color: AppStyles.textPrimary,
              fontSize: 28, fontWeight: FontWeight.bold)),
          SizedBox(height: 24),
          CircularProgressIndicator(color: AppStyles.primary),
        ])),
      );
    }

    // У админа считаем только избранные ЗАПИСИ (не услуги клиента)
    final favCount = provider.favoriteAppointments.length;

    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        title: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppStyles.primaryGradient,
            ),
            child: const Icon(Icons.local_car_wash,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(_titles[_index], style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600,
              color: AppStyles.textPrimary)),
          Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppStyles.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Администратор',
                style: TextStyle(color: AppStyles.primary, fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
        // Кнопка выхода убрана из appBar — только в drawer
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
      floatingActionButton: _index == 2 ? null :
        FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: Text(_index == 0 ? 'Новая запись' : 'Новая услуга'),
          backgroundColor: AppStyles.primary,
          foregroundColor: Colors.white,
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => _index == 0
                ? const AddEditAppointmentScreen()
                : const AddEditServiceScreen(),
          )),
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppStyles.border)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppStyles.primaryBg,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined,
                  color: AppStyles.textSecondary),
              selectedIcon: Icon(Icons.calendar_today, color: AppStyles.primary),
              label: 'Записи',
            ),
            const NavigationDestination(
              icon: Icon(Icons.local_car_wash, color: AppStyles.textSecondary),
              selectedIcon: Icon(Icons.local_car_wash, color: AppStyles.primary),
              label: 'Услуги',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: favCount > 0,
                label: Text('$favCount'),
                backgroundColor: AppStyles.primary,
                child: const Icon(Icons.star_outline,
                    color: AppStyles.textSecondary),
              ),
              selectedIcon: Icon(Icons.star, color: AppStyles.primary),
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
      backgroundColor: Colors.white,
      child: SafeArea(
        bottom: false,
        child: ListView(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          color: Colors.white,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppStyles.primaryGradient,
                boxShadow: [BoxShadow(
                  color: AppStyles.primary.withOpacity(0.3),
                  blurRadius: 20,
                )],
              ),
              child: const Icon(Icons.local_car_wash,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 14),
            const Text('LanWash',
                style: TextStyle(color: AppStyles.textPrimary,
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppStyles.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(auth.username,
                  style: const TextStyle(color: AppStyles.primary, fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        const Divider(color: AppStyles.border, height: 1),
        const SizedBox(height: 8),
        _drawerItem(ctx, 0, Icons.calendar_today_outlined,
            Icons.calendar_today, 'Записи на мойку', null),
        _drawerItem(ctx, 1, Icons.local_car_wash,
            Icons.local_car_wash, 'Каталог услуг', null),
        _drawerItem(ctx, 2, Icons.star_outline,
            Icons.star, 'Избранное', favCount > 0 ? '$favCount' : null),
        const Divider(color: AppStyles.border, indent: 16, endIndent: 16),
        // Расписание
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            minLeadingWidth: 24,
            leading: const Icon(Icons.calendar_month_outlined,
                color: AppStyles.textSecondary, size: 22),
            title: const Text('Расписание',
                style: TextStyle(color: AppStyles.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => const AdminScheduleScreen()));
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
              isLabelVisible: context.watch<AppProvider>().unreadNotes > 0,
              label: Text('${context.watch<AppProvider>().unreadNotes}'),
              backgroundColor: AppStyles.danger,
              child: const Icon(Icons.note_alt_outlined,
                  color: AppStyles.textSecondary, size: 22),
            ),
            title: const Text('Заметки мойщиков',
                style: TextStyle(color: AppStyles.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => const NotesScreen()));
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
            leading: const Icon(Icons.history_rounded,
                color: AppStyles.textSecondary, size: 22),
            title: const Text('Журнал действий',
                style: TextStyle(color: AppStyles.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => const LogsScreen()));
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
            leading: const Icon(Icons.person_outline_rounded,
                color: AppStyles.textSecondary, size: 22),
            title: const Text('Профиль',
                style: TextStyle(color: AppStyles.textPrimary)),
            onTap: () {
              Navigator.pop(ctx);
              Navigator.push(ctx, MaterialPageRoute(
                  builder: (_) => const ProfileScreen()));
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
            title: const Text('Сменить профиль',
                style: TextStyle(color: AppStyles.textSecondary)),
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
        leading: Icon(sel ? selIcon : icon, size: 22,
            color: sel ? AppStyles.primary : AppStyles.textSecondary),
        title: Text(label, style: TextStyle(
          color: sel ? AppStyles.primary : AppStyles.textPrimary,
          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
        )),
        trailing: badge != null ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppStyles.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(badge, style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ) : null,
        selected: sel,
        selectedTileColor: AppStyles.primary.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () { setState(() => _index = index); Navigator.pop(ctx); },
      ),
    );
  }
}
