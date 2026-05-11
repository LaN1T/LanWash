import 'dart:async'; // Add this
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart'; // Add this
import '../profile_screen.dart';
import 'client_home_screen.dart';
import 'my_bookings_screen.dart';
import 'client_favorites_screen.dart';
import '../services_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});
  static final shellKey = GlobalKey<_ClientShellState>();
  @override State<ClientShell> createState() => _ClientShellState();
}

class _ClientShellState extends State<ClientShell> {
  int _index = 0;
  StreamSubscription? _appointmentSub; // Add this

  void switchToBookings() => setState(() => _index = 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<AppProvider>().reloadForUser(auth.userLogin, auth);

      // Listen for updates
      _appointmentSub = NotificationService().onAppointmentUpdated.listen((id) {
        if (mounted) {
          context.read<AppProvider>().reloadForUser(auth.userLogin, auth);
        }
      });
    });
  }

  @override
  void dispose() {
    _appointmentSub?.cancel(); // Cancel subscription
    super.dispose();
  }

  static const _titles = ['Главная', 'Мои записи', 'Избранное'];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final auth     = context.watch<AuthProvider>();
    // Считаем только избранные каталожные услуги (не extra), чтобы не путать с admin
    final favCount = provider.favoriteServices.length;
    final hasUnseenChanges = provider.appointments.any((a) => (a.isModifiedByAdmin || a.isModifiedByWasher) && !a.isSeenByClient) || provider.hasDeletedByAdmin;

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
        title: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppStyles.primaryGradient,
            ),
            child: const Icon(Icons.local_car_wash,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(_titles[_index], style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700,
              color: AppStyles.textPrimary)),
        ]),
      ),
      drawer: _buildDrawer(context, favCount, auth),
      body: IndexedStack(index: _index, children: const [
        ClientHomeScreen(),
        MyBookingsScreen(),
        ClientFavoritesScreen(),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppStyles.border)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, -4))],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            // 1. Обновляем текущую вкладку
            setState(() => _index = i);

            // 2. Сбрасываем только флаг удаления при переходе на "Записи"
            if (i == 1) {
              context.read<AppProvider>().clearDeletedByAdminFlag();
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppStyles.primaryBg,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppStyles.primary),
              label: 'Главная',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: hasUnseenChanges,
                label: const Text('!'),
                backgroundColor: AppStyles.danger,
                child: const Icon(Icons.calendar_today_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: hasUnseenChanges,
                label: const Text('!'),
                backgroundColor: AppStyles.danger,
                child: const Icon(Icons.calendar_today_rounded,
                    color: AppStyles.primary),
              ),
              label: 'Записи',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: favCount > 0,
                label: Text('$favCount'),
                backgroundColor: AppStyles.primary,
                child: const Icon(Icons.star_outline),
              ),
              selectedIcon: Icon(Icons.star_rounded, color: AppStyles.primary),
              label: 'Избранное',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext ctx, int favCount, AuthProvider auth) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
        // Шапка
        Container(
          width: double.infinity,
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
        _drawerItem(ctx, 0, Icons.home_outlined,
            Icons.home_rounded, 'Главная', null),
        _drawerItem(ctx, 1, Icons.calendar_today_outlined,
            Icons.calendar_today_rounded, 'Мои записи', null),
        _drawerItem(ctx, 2, Icons.star_outline,
            Icons.star_rounded, 'Избранное',
            favCount > 0 ? '$favCount' : null),

        const Divider(color: AppStyles.border, indent: 16, endIndent: 16),
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
              color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.bold)),
        ) : null,
        selected: sel,
        selectedTileColor: AppStyles.primary.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        onTap: () {
          setState(() => _index = index);
          Navigator.pop(ctx);
        },
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
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена')),
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