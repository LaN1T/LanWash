import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_styles.dart';
import '../models/appointment.dart';
import '../providers/app_provider.dart';
import 'appointment_detail_screen.dart';
import 'add_edit_appointment_screen.dart';
import '../models/service.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});
  @override State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  String _filterStatus = 'all';
  final _search = TextEditingController();
  String _searchText = '';

  static const _filters = [
    ('all', 'Все'),
    ('scheduled',   'Запланированы'),
    ('in_progress', 'В процессе'),
    ('completed',   'Завершены'),
  ];

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  List<Appointment> _filtered(List<Appointment> all) {
    return all.where((a) {
      final matchStatus = _filterStatus == 'all' || a.status == _filterStatus;
      final q = _searchText.toLowerCase();
      final matchSearch = q.isEmpty ||
          a.clientName.toLowerCase().contains(q) ||
          a.carModel.toLowerCase().contains(q) ||
          a.carNumber.toLowerCase().contains(q);
      return matchStatus && matchSearch;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    if (provider.loading) return const Center(child: CircularProgressIndicator());

    final list = _filtered(provider.appointments);

    return Column(children: [
      _buildSearchBar(),
      _buildFilters(),
      Expanded(
        child: list.isEmpty
            ? _emptyState()
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: list.length,
                itemBuilder: (ctx, i) => _AppointmentCard(
                  appointment: list[i],
                  services: provider.services,
                  onFavorite: () => provider.toggleAppointmentFavorite(list[i].id),
                  onTap: () => Navigator.push(ctx,
                    MaterialPageRoute(builder: (_) => AppointmentDetailScreen(appointment: list[i]))),
                ),
              ),
      ),
    ]);
  }

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
    child: TextField(
      controller: _search,
      onChanged: (v) => setState(() => _searchText = v),
      decoration: AppStyles.inputDecoration('Поиск по клиенту, авто, номеру', icon: Icons.search),
      style: AppStyles.bodyLarge,
    ),
  );

  Widget _buildFilters() => SizedBox(
    height: 48,
    child: ListView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      scrollDirection: Axis.horizontal,
      children: _filters.map((f) {
        final selected = _filterStatus == f.$1;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(f.$2),
            selected: selected,
            onSelected: (_) => setState(() => _filterStatus = f.$1),
            selectedColor: AppStyles.primary,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppStyles.textSecondary,
              fontSize: 13,
            ),
          ),
        );
      }).toList(),
    ),
  );

  Widget _emptyState() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.calendar_today_outlined, size: 64, color: AppStyles.textSecondary.withOpacity(0.4)),
      const SizedBox(height: 12),
      Text('Нет записей', style: AppStyles.headingMedium.copyWith(color: AppStyles.textSecondary)),
      const SizedBox(height: 6),
      Text('Нажмите + чтобы добавить запись', style: AppStyles.bodyMedium),
    ]),
  );
}

// ─── Карточка записи ─────────────────────────────────────────────────────────
class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final List<dynamic> services;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  const _AppointmentCard({required this.appointment, required this.services, required this.onFavorite, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final dateStr = DateFormat('d MMM, HH:mm', 'ru').format(a.dateTime);
    final statusColor = AppStyles.statusColor(a.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: AppStyles.cardDecoration,
        child: Padding(
          padding: AppStyles.cardPadding,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Статус-иконка
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(AppStyles.statusIcon(a.status), color: statusColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.clientName, style: AppStyles.headingMedium, overflow: TextOverflow.ellipsis),
                Text(a.carModel, style: AppStyles.bodyMedium),
              ])),
              IconButton(
                icon: Icon(a.isFavorite ? Icons.star : Icons.star_border,
                    color: a.isFavorite ? AppStyles.favorite : AppStyles.textSecondary),
                onPressed: onFavorite,
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ),
            ]),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppStyles.divider),
            const SizedBox(height: 10),
            Row(children: [
              _info(Icons.calendar_today,  dateStr),
              const SizedBox(width: 16),
              _info(Icons.pin,             a.carNumber),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(AppStyles.statusLabel(a.status),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              _info(Icons.local_car_wash, context.watch<AppProvider>().washTypeName(a.washTypeId)),
              const Spacer(),
              if (a.priceChanged) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${a.paidPrice} ₽', style: AppStyles.price.copyWith(fontSize: 15)),
                Text('${a.originalPrice} ₽', style: const TextStyle(
                  fontSize: 12, color: AppStyles.textSecondary,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppStyles.textSecondary,
                )),
              ]) else
                Text('${a.calculateTotalPrice(services.cast<Service>(), context.watch<AppProvider>().washTypeById(a.washTypeId))} ₽', style: AppStyles.price.copyWith(fontSize: 15)),
            ]),
            if (a.additionalServices.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 4, children: a.additionalServices.map((id) {
                final service = services.firstWhere((s) => s.id == id, orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: ''));
                final name = service.name;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppStyles.primaryLight.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(name, style: AppStyles.bodySmall.copyWith(color: AppStyles.primaryDark)),
                );
              }).toList()),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _info(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 14, color: AppStyles.textSecondary),
    const SizedBox(width: 4),
    Text(text, style: AppStyles.bodySmall),
  ]);
}