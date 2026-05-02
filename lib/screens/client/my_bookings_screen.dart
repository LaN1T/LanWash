import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/service.dart';



class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});
  @override State<MyBookingsScreen> createState() => _State();
}

class _State extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppProvider>().clearDeletedByAdminFlag();
    });
  }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final auth     = context.watch<AuthProvider>();
    final username = auth.userLogin.toLowerCase();

    // Клиент видит только свои записи (по ownerUsername), админ — все
    final all = auth.isAdmin
        ? provider.appointments
        : provider.appointments
            .where((a) =>
                a.ownerUsername.toLowerCase() == username ||
                // fallback для демо-записей у которых нет ownerUsername
                (a.ownerUsername.isEmpty && a.clientName.toLowerCase() == username))
            .toList();

    final upcoming = all
        .where((a) => a.status == 'scheduled' || a.status == 'in_progress')
        .toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final history = all
        .where((a) => a.status == 'completed' || a.status == 'cancelled')
        .toList()..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Container(
      color: AppStyles.bgPage,
      child: Column(children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            labelColor: AppStyles.primary,
            unselectedLabelColor: AppStyles.textSecondary,
            indicatorColor: AppStyles.primary,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(text: 'Активные (${upcoming.length})'),
              Tab(text: 'История (${history.length})'),
            ],
          ),
        ),
        Expanded(child: TabBarView(controller: _tab, children: [
          _BookingsList(items: upcoming,
              services: provider.services,
              emptyText: 'Нет активных записей',
              emptyIcon: Icons.calendar_today_outlined),
          _BookingsList(items: history,
              services: provider.services,
              emptyText: 'История пуста',
              emptyIcon: Icons.history_rounded),
        ])),
      ]),
    );
  }
}

class _BookingsList extends StatelessWidget {
  final List<Appointment> items;
  final List<dynamic> services;
  final String emptyText;
  final IconData emptyIcon;
  const _BookingsList({required this.items, required this.services, required this.emptyText,
    required this.emptyIcon});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return Center(child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
              color: AppStyles.primaryBg, shape: BoxShape.circle),
          child: Icon(emptyIcon, size: 40, color: AppStyles.primary),
        ),
        const SizedBox(height: 16),
        Text(emptyText, style: const TextStyle(color: AppStyles.textSecondary,
            fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        const Text('Здесь появятся ваши записи', style: AppStyles.bodyMedium),
      ],
    ));

    return ListView.builder(
      padding: AppStyles.pagePadding,
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final a = items[i];
        final color   = AppStyles.statusColor(a.status);
        final bgColor = AppStyles.statusBgColor(a.status);
        return GestureDetector(
          onTap: () {
            // При просмотре записи отмечаем её как прочитанную
            ctx.read<AppProvider>().markAsSeen(a.id);
            if (a.isModifiedByAdmin) {
              ctx.read<AppProvider>().clearAdminModifiedFlag(a.id);
            }
          },
          child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: AppStyles.cardDecoration,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ─ Заголовок карточки ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: bgColor, borderRadius: BorderRadius.circular(10)),
                  child: Icon(AppStyles.statusIcon(a.status), color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(ctx.watch<AppProvider>().washTypeName(a.washTypeId),
                      style: const TextStyle(color: AppStyles.textPrimary,
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Text('${a.carModel} · ${a.carNumber}',
                        style: AppStyles.bodySmall),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppStyles.primaryBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('Бокс №${a.box_index + 1}',
                          style: AppStyles.bodySmall.copyWith(
                              color: AppStyles.primary, fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ])),
                if (a.isModifiedByAdmin && !a.isSeenByClient)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 24, height: 24,
                    decoration: const BoxDecoration(
                      color: AppStyles.danger,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('!', style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      )),
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: bgColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(AppStyles.statusLabel(a.status),
                      style: TextStyle(color: color, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
            // ─ Детали ───────────────────────────────────────────────────
            Container(height: 1, color: AppStyles.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                const Icon(Icons.event_rounded,
                    size: 14, color: AppStyles.textSecondary),
                const SizedBox(width: 6),
                Builder(builder: (context) {
                  final provider = context.watch<AppProvider>();
                  final washType = provider.washTypeById(a.washTypeId);
                  final duration = a.calculateTotalPrice(services.cast<Service>(), washType) >= 0 
                      ? (washType?.durationMinutes ?? 30) + 
                        a.additionalServices.where((id) => !(washType?.includedExtraIds.contains(id) ?? false)).fold(0, (sum, id) => sum + (provider.services.firstWhere((s) => s.id == id, orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: '')).durationMinutes))
                      : 30;
                  final endTime = a.dateTime.add(Duration(minutes: duration.toInt()));
                  return Text('${DateFormat('d MMM, HH:mm', 'ru').format(a.dateTime)} — ${DateFormat('HH:mm').format(endTime)}',
                      style: const TextStyle(color: AppStyles.primary,
                          fontSize: 12, fontWeight: FontWeight.w500));
                }),
                const Spacer(),
                if (a.priceChanged) ...[
                  Text('${a.originalPrice} ₽',
                      style: const TextStyle(
                          color: AppStyles.textSecondary,
                          fontSize: 12,
                          decoration: TextDecoration.lineThrough,
                          decorationColor: AppStyles.textSecondary)),
                  const SizedBox(width: 6),
                ],
                Text('${a.calculateTotalPrice(services.cast<Service>(), context.watch<AppProvider>().washTypeById(a.washTypeId))} ₽',
                    style: const TextStyle(color: AppStyles.primary,
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
            ),
            if (a.additionalServices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(spacing: 6, runSpacing: 4,
                  children: a.additionalServices.map((id) {
                    final service = context.watch<AppProvider>().services.firstWhere((s) => s.id == id, orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: ''));
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppStyles.primaryBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(service.name, style: const TextStyle(
                          color: AppStyles.primary, fontSize: 11)),
                    );
                  }).toList()),
              ),
          ]),
        ));
      },
    );
  }
}