import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_styles.dart';
import '../models/appointment.dart';
import '../models/service.dart';
import '../providers/app_provider.dart';
import 'appointment_detail_screen.dart';
import 'service_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          color: Colors.white,
          child: const TabBar(
            labelColor: AppStyles.primary,
            unselectedLabelColor: AppStyles.textSecondary,
            indicatorColor: AppStyles.primary,
            tabs: [
              Tab(icon: Icon(Icons.calendar_today, size: 18), text: 'Записи'),
              Tab(icon: Icon(Icons.local_car_wash,        size: 18), text: 'Услуги'),
            ],
          ),
        ),
        const Expanded(
          child: TabBarView(children: [
            _FavAppointmentsTab(),
            _FavServicesTab(),
          ]),
        ),
      ]),
    );
  }
}

// ─── Вкладка: Избранные записи ────────────────────────────────────────────────
class _FavAppointmentsTab extends StatelessWidget {
  const _FavAppointmentsTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final favs = provider.favoriteAppointments;

    if (favs.isEmpty) return _empty('Нет избранных записей', Icons.calendar_today_outlined);

    return ListView.builder(
      padding: AppStyles.pagePadding,
      itemCount: favs.length,
      itemBuilder: (ctx, i) => _FavAppointmentTile(
        appointment: favs[i],
        onRemove: () => provider.toggleAppointmentFavorite(favs[i].id),
        onTap: () => Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => AppointmentDetailScreen(appointment: favs[i]))),
      ),
    );
  }
}

class _FavAppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  const _FavAppointmentTile({required this.appointment, required this.onRemove, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final statusColor = AppStyles.statusColor(a.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppStyles.cardDecoration,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppStyles.favorite.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star, color: AppStyles.favorite, size: 22),
          ),
          title: Text(a.clientName, style: AppStyles.headingMedium.copyWith(fontSize: 15)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 2),
            Text('${a.carModel} · ${a.carNumber}', style: AppStyles.bodySmall),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(AppStyles.statusLabel(a.status),
                    style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(DateFormat('d MMM, HH:mm', 'ru').format(a.dateTime), style: AppStyles.bodySmall),
            ]),
          ]),
          trailing: IconButton(
            icon: const Icon(Icons.star, color: AppStyles.favorite),
            tooltip: 'Убрать из избранного',
            onPressed: () => _confirmRemove(context, onRemove, a.clientName),
          ),
        ),
      ),
    );
  }
}

// ─── Вкладка: Избранные услуги ────────────────────────────────────────────────
class _FavServicesTab extends StatelessWidget {
  const _FavServicesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final favs = provider.favoriteServices;

    if (favs.isEmpty) return _empty('Нет избранных услуг', Icons.local_car_wash);

    return ListView.builder(
      padding: AppStyles.pagePadding,
      itemCount: favs.length,
      itemBuilder: (ctx, i) => _FavServiceTile(
        service: favs[i],
        onRemove: () => provider.toggleServiceFavorite(favs[i].id),
        onTap: () => Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => ServiceDetailScreen(service: favs[i]))),
      ),
    );
  }
}

class _FavServiceTile extends StatelessWidget {
  final Service service;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  const _FavServiceTile({required this.service, required this.onRemove, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = service;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppStyles.cardDecoration,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppStyles.favorite.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star, color: AppStyles.favorite, size: 22),
          ),
          title: Text(s.name, style: AppStyles.headingMedium.copyWith(fontSize: 15)),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 2),
            Text(s.category, style: AppStyles.bodySmall),
            const SizedBox(height: 4),
            Row(children: [
              Text(s.durationLabel, style: AppStyles.bodySmall),
              const SizedBox(width: 12),
              Text('${s.price} ₽', style: AppStyles.price.copyWith(fontSize: 14)),
            ]),
          ]),
          trailing: IconButton(
            icon: const Icon(Icons.star, color: AppStyles.favorite),
            tooltip: 'Убрать из избранного',
            onPressed: () => _confirmRemove(context, onRemove, s.name),
          ),
        ),
      ),
    );
  }
}

// ─── Утилиты ─────────────────────────────────────────────────────────────────
Widget _empty(String text, IconData icon) => Center(
  child: Column(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 64, color: AppStyles.textSecondary.withOpacity(0.3)),
    const SizedBox(height: 12),
    Text(text, style: AppStyles.bodyLarge.copyWith(color: AppStyles.textSecondary)),
    const SizedBox(height: 6),
    const Text('Нажмите ★ на любой записи или услуге', style: AppStyles.bodyMedium),
  ]),
);

void _confirmRemove(BuildContext ctx, VoidCallback onConfirm, String name) {
  showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      title: const Text('Убрать из избранного?'),
      content: Text('«$name» будет удалён из избранного.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        TextButton(
          onPressed: () { Navigator.pop(ctx); onConfirm(); },
          child: const Text('Убрать', style: TextStyle(color: AppStyles.danger)),
        ),
      ],
    ),
  );
}
