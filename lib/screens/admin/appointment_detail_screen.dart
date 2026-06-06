import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/service.dart';
import 'add_edit_appointment_screen.dart';

class AppointmentDetailScreen extends StatelessWidget {
  final Appointment appointment;
  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final a = provider.appointments.firstWhere(
      (x) => x.id == appointment.id,
      orElse: () => appointment,
    );

    final bool canEdit = !auth.isWasher;

    return Scaffold(
      backgroundColor: AppStyles.background,
      appBar: AppBar(
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Детали записи',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(a.isFavorite ? Icons.star : Icons.star_border,
                color: a.isFavorite ? AppStyles.favorite : Colors.white70),
            onPressed: () => provider.toggleAppointmentFavorite(a.id),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppStyles.pagePadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StatusBanner(status: a.status),
          const SizedBox(height: 16),
          if (auth.isWasher &&
              (a.status == 'scheduled' || a.status == 'in_progress')) ...[
            _SectionTitle('Управление статусом'),
            _StatusSelector(
              currentStatus: a.status,
              onChanged: (newStatus) async {
                final success = await provider.updateAppointment(
                    a.copyWith(status: newStatus), auth);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          'Статус обновлен на: ${AppStyles.statusLabel(newStatus)}')));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
          _Section(title: 'Клиент и автомобиль', children: [
            _Row(Icons.person, 'Клиент', a.clientName),
            _Row(Icons.directions_car, 'Автомобиль', a.carModel),
            _Row(Icons.pin, 'Номер', a.carNumber),
          ]),
          const SizedBox(height: 12),
          _Section(title: 'Дата и время', children: [
            _Row(Icons.calendar_today, 'Дата',
                DateFormat('d MMMM yyyy', 'ru').format(a.dateTime)),
            Builder(builder: (context) {
              final washType = provider.washTypeById(a.washTypeId);
              final duration =
                  a.calculateTotalPrice(provider.services, washType) >= 0
                      ? (washType?.durationMinutes ?? 30) +
                          a.additionalServices
                              .where((id) =>
                                  !(washType?.includedExtraIds.contains(id) ??
                                      false))
                              .fold(
                                  0,
                                  (sum, id) =>
                                      sum +
                                      (provider.services
                                          .firstWhere((s) => s.id == id,
                                              orElse: () => Service(
                                                  id: id,
                                                  name: id,
                                                  description: '',
                                                  price: 0,
                                                  durationMinutes: 0,
                                                  category: '',
                                                  isFavorite: false,
                                                  isFromApi: false))
                                          .durationMinutes))
                      : 30;
              final endTime =
                  a.dateTime.add(Duration(minutes: duration.toInt()));
              final cutoff = DateTime(
                  a.dateTime.year, a.dateTime.month, a.dateTime.day, 22, 0);
              String timeStr;
              if (endTime.isAfter(cutoff)) {
                final overflow = endTime.difference(cutoff).inMinutes;
                timeStr =
                    '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — 22:00, ⚠ Завтра до ${((8 * 60 + overflow) ~/ 60).toString().padLeft(2, '0')}:${((8 * 60 + overflow) % 60).toString().padLeft(2, '0')}';
              } else {
                timeStr =
                    '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — ${DateFormat('HH:mm').format(endTime)}';
              }
              return _Row(Icons.access_time, 'Время', timeStr);
            }),
          ]),
          const SizedBox(height: 12),
          _Section(title: 'Тип мойки', children: [
            _Row(Icons.local_car_wash, 'Пакет',
                provider.washTypeName(a.washTypeId)),
            _Row(Icons.payments, 'Итого',
                '${a.priceChanged ? a.paidPrice : a.calculateTotalPrice(provider.services, provider.washTypeById(a.washTypeId))} ₽'),
            if (a.priceChanged)
              _PriceChangedRow(
                  newPrice: a.paidPrice, oldPrice: a.originalPrice),
          ]),
          const SizedBox(height: 12),
          if (a.additionalServices.isNotEmpty) ...[
            _SectionTitle('Дополнительные услуги'),
            Container(
              decoration: AppStyles.cardDecoration,
              padding: AppStyles.cardPadding,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: a.additionalServices.map((id) {
                  final service = context
                      .watch<AppProvider>()
                      .services
                      .firstWhere((s) => s.id == id,
                          orElse: () => Service(
                              id: id,
                              name: id,
                              description: '',
                              price: 0,
                              durationMinutes: 0,
                              category: ''));
                  return Chip(
                    label: Text(service.name,
                        style: const TextStyle(fontSize: 13)),
                    backgroundColor: AppStyles.primary.withValues(alpha:0.1),
                    side: BorderSide(color: AppStyles.primary.withValues(alpha:0.3)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (a.notes.isNotEmpty) ...[
            _SectionTitle('Заметки'),
            Container(
              width: double.infinity,
              decoration: AppStyles.cardDecoration,
              padding: AppStyles.cardPadding,
              child: Text(a.notes, style: AppStyles.bodyLarge),
            ),
            const SizedBox(height: 12),
          ],
          if (canEdit) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Редактировать запись'),
                style: AppStyles.primaryButton,
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            AddEditAppointmentScreen(appointment: a))),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, color: AppStyles.danger),
                label: const Text('Удалить запись',
                    style: TextStyle(color: AppStyles.danger)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppStyles.danger),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _confirmDelete(context, provider, a.id),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить запись?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(context); // закрыть диалог
              final auth = context.read<AuthProvider>();
              provider.deleteAppointment(id, auth);
              Navigator.pop(context); // вернуться в список
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  const _StatusBanner({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = AppStyles.statusColor(status);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha:0.3)),
      ),
      child: Row(children: [
        Icon(AppStyles.statusIcon(status), color: color, size: 28),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Статус записи', style: AppStyles.label),
          Text(AppStyles.statusLabel(status),
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: color)),
        ]),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _SectionTitle(title),
        Container(
          decoration: AppStyles.cardDecoration,
          child: Column(
              children: children.map((c) {
            final i = children.indexOf(c);
            return Column(children: [
              c,
              if (i < children.length - 1)
                const Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: AppStyles.divider),
            ]);
          }).toList()),
        ),
      ]);
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(text, style: AppStyles.label.copyWith(fontSize: 13)),
      );
}

class _PriceChangedRow extends StatelessWidget {
  final int newPrice;
  final int oldPrice;
  const _PriceChangedRow({required this.newPrice, required this.oldPrice});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          const Icon(Icons.edit_note_rounded,
              size: 18, color: AppStyles.primary),
          const SizedBox(width: 12),
          SizedBox(
              width: 100, child: Text('Изменено', style: AppStyles.bodyMedium)),
          Expanded(
              child:
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$newPrice ₽',
                style: AppStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600, color: AppStyles.primary)),
            Text('$oldPrice ₽',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppStyles.textSecondary,
                  decoration: TextDecoration.lineThrough,
                  decorationColor: AppStyles.textSecondary,
                )),
          ])),
        ]),
      );
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 18, color: AppStyles.primary),
          const SizedBox(width: 12),
          // Фиксированная ширина лейбла — выровниваем все значения
          SizedBox(
            width: 100,
            child: Text(label, style: AppStyles.bodyMedium),
          ),
          Expanded(
              child: Text(value,
                  style:
                      AppStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500),
                  textAlign: TextAlign.right)),
        ]),
      );
}

class _StatusSelector extends StatelessWidget {
  final String currentStatus;
  final ValueChanged<String> onChanged;

  const _StatusSelector({required this.currentStatus, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final List<String> options = ['scheduled', 'in_progress', 'completed'];
    // Filter options based on business logic
    final List<String> availableOptions;
    if (currentStatus == 'scheduled') {
      availableOptions = ['scheduled', 'in_progress', 'completed'];
    } else if (currentStatus == 'in_progress') {
      availableOptions = ['in_progress', 'completed'];
    } else {
      availableOptions = [currentStatus];
    }

    return Container(
      decoration: AppStyles.cardDecoration,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentStatus,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down_circle_outlined,
              color: AppStyles.primary),
          borderRadius: BorderRadius.circular(16),
          items: availableOptions
              .map((s) => DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Icon(AppStyles.statusIcon(s),
                            color: AppStyles.statusColor(s), size: 20),
                        const SizedBox(width: 12),
                        Text(AppStyles.statusLabel(s),
                            style: AppStyles.bodyLarge.copyWith(
                              color: AppStyles.statusColor(s),
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null && v != currentStatus) {
              onChanged(v);
            }
          },
        ),
      ),
    );
  }
}
