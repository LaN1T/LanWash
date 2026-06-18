import 'dart:async'; // Add this
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/favorite_provider.dart';
import '../../providers/support_provider.dart';
import '../../services/notification_service.dart'; // Add this
import '../../widgets/offline_status_indicator.dart';
import '../shared/profile_screen.dart';
import '../shared/splash_screen.dart';
import 'client_home_screen.dart';
import 'my_bookings_screen.dart';
import 'client_favorites_screen.dart';
import 'support_chats_screen.dart';

class ClientShell extends StatefulWidget {
  const ClientShell({super.key});
  static final shellKey = GlobalKey<_ClientShellState>();
  @override
  State<ClientShell> createState() => _ClientShellState();
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
      context.read<AppointmentProvider>().reloadForUser(auth.userLogin, auth);
    });

    _appointmentSub = NotificationService().onAppointmentUpdated.listen((id) {
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      context.read<AppointmentProvider>().reloadForUser(auth.userLogin, auth);
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
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        title: Row(children: [
          const LanWashLogo(
            circleSize: 34,
            showTitle: false,
            showSubtitle: false,
            showLoader: false,
            shadowBlur: null,
          ),
          const SizedBox(width: 10),
          Text(_titles[_index],
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        ]),
        actions: const [
          OfflineStatusIndicator(),
        ],
      ),
      drawer: _buildDrawer(context),
      body: IndexedStack(index: _index, children: const [
        ClientHomeScreen(),
        MyBookingsScreen(),
        ClientFavoritesScreen(),
      ]),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppStyles.adaptiveCard(context),
          border:
              Border(top: BorderSide(color: AppStyles.adaptiveBorder(context))),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, -4))
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) {
            // 1. Обновляем текущую вкладку
            setState(() => _index = i);

            // 2. Сбрасываем только флаг удаления при переходе на "Записи"
            if (i == 1) {
              context.read<AppointmentProvider>().clearDeletedByAdminFlag();
            }
          },
          backgroundColor: Colors.transparent,
          elevation: 0,
          indicatorColor: AppStyles.adaptivePrimaryBg(context),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: AppStyles.primary),
              label: 'Главная',
            ),
            NavigationDestination(
              icon: _AppointmentsBadge(),
              selectedIcon: _AppointmentsBadge(selected: true),
              label: 'Записи',
            ),
            NavigationDestination(
              icon: _FavoritesBadge(),
              selectedIcon: _FavoritesBadge(selected: true),
              label: 'Избранное',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext ctx) {
    final username = ctx.watch<AuthProvider>().username;
    final catalog = ctx.watch<CatalogProvider>();
    final favSet = ctx.watch<FavoriteProvider>().serviceFavorites;
    final favCount = catalog.services.where((s) => favSet.contains(s.id)).length;
    return Drawer(
      backgroundColor: AppStyles.adaptiveCard(ctx),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          // Шапка
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
          _drawerItem(
              ctx, 0, Icons.home_outlined, Icons.home_rounded, 'Главная', null),
          _drawerItem(ctx, 1, Icons.calendar_today_outlined,
              Icons.calendar_today_rounded, 'Мои записи', null),
          _drawerItem(ctx, 2, Icons.star_outline, Icons.star_rounded,
              'Избранное', favCount > 0 ? '$favCount' : null),


          Divider(
              color: AppStyles.adaptiveBorder(ctx), indent: 16, endIndent: 16),
          // Чат с поддержкой
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: ListTile(
              minLeadingWidth: 24,
              leading: _SupportBadge(),
              title: Text('Чат с поддержкой',
                  style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                    ctx,
                    MaterialPageRoute(
                        builder: (_) => const SupportChatsScreen()));
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

class _AppointmentsBadge extends StatelessWidget {
  final bool selected;
  const _AppointmentsBadge({this.selected = false});

  @override
  Widget build(BuildContext context) {
    final ap = context.watch<AppointmentProvider>();
    final hasUnseenChanges = ap.appointments.any((a) =>
            (a.isModifiedByAdmin || a.isModifiedByWasher) &&
            !a.isSeenByClient) ||
        ap.hasDeletedByAdmin;

    return Badge(
      isLabelVisible: hasUnseenChanges,
      label: const Text('!'),
      backgroundColor: AppStyles.danger,
      child: Icon(
        selected ? Icons.calendar_today_rounded : Icons.calendar_today_outlined,
        color: selected ? AppStyles.primary : null,
      ),
    );
  }
}

class _FavoritesBadge extends StatelessWidget {
  final bool selected;
  const _FavoritesBadge({this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Selector2<CatalogProvider, FavoriteProvider, int>(
      selector: (_, catalog, favorite) => catalog.services
          .where((s) => favorite.serviceFavorites.contains(s.id))
          .length,
      builder: (_, favCount, __) => Badge(
        isLabelVisible: favCount > 0,
        label: Text('$favCount'),
        backgroundColor: AppStyles.primary,
        child: Icon(
          selected ? Icons.star_rounded : Icons.star_outline,
          color: selected ? AppStyles.primary : null,
        ),
      ),
    );
  }
}

class _SupportBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final count = context.watch<SupportProvider>().unreadClientCount;

    return Badge(
      isLabelVisible: count > 0,
      label: Text('$count'),
      backgroundColor: AppStyles.danger,
      child: Icon(Icons.support_agent_outlined,
          color: AppStyles.adaptiveTextSecondary(context), size: 22),
    );
  }
}
