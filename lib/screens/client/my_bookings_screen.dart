import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';

// Хелпер — не зависит от extension, работает надёжно на web
String _washName(WashType t) => switch (t) {
  WashType.basic   => 'Базовая мойка',
  WashType.complex => 'Комплексная мойка',
  WashType.premium => 'Премиум мойка',
};

int _washPrice(WashType t) => switch (t) {
  WashType.basic   => 800,
  WashType.complex => 1500,
  WashType.premium => 3000,
};

// Цены доп. услуг (дублируем чтобы не зависеть от booking_wizard)


class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});
  @override State<MyBookingsScreen> createState() => _State();
}

class _State extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); }
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
              emptyText: 'Нет активных записей',
              emptyIcon: Icons.calendar_today_outlined),
          _BookingsList(items: history,
              emptyText: 'История пуста',
              emptyIcon: Icons.history_rounded),
        ])),
      ]),
    );
  }
}

class _BookingsList extends StatelessWidget {
  final List<Appointment> items;
  final String emptyText;
  final IconData emptyIcon;
  const _BookingsList({required this.items, required this.emptyText,
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
      itemBuilder: (_, i) {
        final a = items[i];
        final color   = AppStyles.statusColor(a.status);
        final bgColor = AppStyles.statusBgColor(a.status);
        return Container(
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
                  Text(_washName(a.washType),
                      style: const TextStyle(color: AppStyles.textPrimary,
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text('${a.carModel} · ${a.carNumber}',
                      style: AppStyles.bodySmall),
                ])),
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
                Text(DateFormat('d MMMM yyyy, HH:mm', 'ru').format(a.dateTime),
                    style: const TextStyle(color: AppStyles.primary,
                        fontSize: 12, fontWeight: FontWeight.w500)),
                const Spacer(),
                Text('${a.totalPrice} ₽',
                    style: const TextStyle(color: AppStyles.primary,
                        fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
            ),
            if (a.additionalServices.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Wrap(spacing: 6, runSpacing: 4,
                  children: a.additionalServices.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppStyles.primaryBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(s, style: const TextStyle(
                        color: AppStyles.primary, fontSize: 11)),
                  )).toList()),
              ),
          ]),
        );
      },
    );
  }
}
