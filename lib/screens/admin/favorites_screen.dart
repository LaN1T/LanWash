import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../models/service.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/favorite_provider.dart';
import 'appointment_detail_screen.dart';
import 'service_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        TabBar(
          labelColor: AppStyles.primary,
          unselectedLabelColor: AppStyles.adaptiveTextSecondary(context),
          indicatorColor: AppStyles.primary,
          tabs: const [
            Tab(icon: Icon(Icons.calendar_today, size: 18), text: 'Записи'),
            Tab(icon: Icon(Icons.local_car_wash, size: 18), text: 'Услуги'),
          ],
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
    final appointmentProvider = context.watch<AppointmentProvider>();
    final favs = appointmentProvider.favoriteAppointments;

    if (favs.isEmpty) {
      return _empty(
          context, 'Нет избранных записей', Icons.calendar_today_outlined);
    }

    return ListView.builder(
      padding: AppStyles.pagePadding,
      itemCount: favs.length,
      itemBuilder: (ctx, i) => _FavAppointmentTile(
        appointment: favs[i],
        onRemove: () => appointmentProvider.toggleAppointmentFavorite(favs[i].id),
        onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
                builder: (_) => AppointmentDetailScreen(appointment: favs[i]))),
      ),
    );
  }
}

class _FavAppointmentTile extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  const _FavAppointmentTile(
      {required this.appointment, required this.onRemove, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final statusColor = AppStyles.statusColor(a.status);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppStyles.cardDecorationFor(context),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppStyles.favorite.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star, color: AppStyles.favorite, size: 22),
          ),
          title: Text(a.clientName,
              style: AppStyles.headingMedium.copyWith(
                  fontSize: 15, color: AppStyles.adaptiveTextPrimary(context))),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 2),
            Text('${a.carModel} · ${a.carNumber}',
                style: AppStyles.bodySmall
                    .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
            const SizedBox(height: 4),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(AppStyles.statusLabel(a.status),
                    style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Text(DateFormat('d MMM, HH:mm', 'ru').format(a.dateTime),
                  style: AppStyles.bodySmall.copyWith(
                      color: AppStyles.adaptiveTextSecondary(context))),
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
    final catalogProvider = context.watch<CatalogProvider>();
    final favoriteProvider = context.watch<FavoriteProvider>();
    final favs = catalogProvider.services.where((s) => favoriteProvider.isServiceFavorite(s.id)).toList();

    if (favs.isEmpty) {
      return _empty(context, 'Нет избранных услуг', Icons.local_car_wash);
    }

    return ListView.builder(
      padding: AppStyles.pagePadding,
      itemCount: favs.length,
      itemBuilder: (ctx, i) => _FavServiceTile(
        service: favs[i],
        onRemove: () => favoriteProvider.toggleServiceFavorite(favs[i].id),
        onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
                builder: (_) => ServiceDetailScreen(service: favs[i]))),
      ),
    );
  }
}

class _FavServiceTile extends StatelessWidget {
  final Service service;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  const _FavServiceTile(
      {required this.service, required this.onRemove, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = service;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppStyles.cardDecorationFor(context),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppStyles.favorite.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.star, color: AppStyles.favorite, size: 22),
          ),
          title: Text(s.name,
              style: AppStyles.headingMedium.copyWith(
                  fontSize: 15, color: AppStyles.adaptiveTextPrimary(context))),
          subtitle:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 2),
            Text(s.category,
                style: AppStyles.bodySmall
                    .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
            const SizedBox(height: 4),
            Row(children: [
              Text(s.durationLabel,
                  style: AppStyles.bodySmall.copyWith(
                      color: AppStyles.adaptiveTextSecondary(context))),
              const SizedBox(width: 12),
              Text('${s.price} ₽',
                  style: AppStyles.price.copyWith(fontSize: 14)),
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
Widget _empty(BuildContext context, String text, IconData icon) => Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon,
            size: 64,
            color: AppStyles.adaptiveTextSecondary(context)
                .withValues(alpha: 0.3)),
        const SizedBox(height: 12),
        Text(text,
            style: AppStyles.bodyLarge
                .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
        const SizedBox(height: 6),
        Text('Нажмите ★ на любой записи или услуге',
            style: AppStyles.bodyMedium
                .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
      ]),
    );

void _confirmRemove(BuildContext ctx, VoidCallback onConfirm, String name) {
  showDialog(
    context: ctx,
    builder: (_) => AlertDialog(
      title: Text('Убрать из избранного?',
          style: TextStyle(color: AppStyles.adaptiveTextPrimary(ctx))),
      content: Text('«$name» будет удалён из избранного.',
          style: TextStyle(color: AppStyles.adaptiveTextSecondary(ctx))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            onConfirm();
          },
          child:
              const Text('Убрать', style: TextStyle(color: AppStyles.danger)),
        ),
      ],
    ),
  );
}
