import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_styles.dart';
import '../models/appointment.dart';
import '../providers/app_provider.dart';
import 'add_edit_appointment_screen.dart';

class AppointmentDetailScreen extends StatelessWidget {
  final Appointment appointment;
  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final a = provider.appointments.firstWhere(
      (x) => x.id == appointment.id, orElse: () => appointment,
    );

    return Scaffold(
      backgroundColor: AppStyles.background,
      appBar: AppBar(
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Детали записи',
            style: TextStyle(color: Colors.white,
                fontSize: 17, fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(a.isFavorite ? Icons.star : Icons.star_border,
                color: a.isFavorite ? AppStyles.favorite : Colors.white70),
            onPressed: () => provider.toggleAppointmentFavorite(a.id),
          ),
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => AddEditAppointmentScreen(appointment: a))),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppStyles.pagePadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _StatusBanner(status: a.status),
          const SizedBox(height: 16),

          _Section(title: 'Клиент и автомобиль', children: [
            _Row(Icons.person,         'Клиент',      a.clientName),
            _Row(Icons.directions_car, 'Автомобиль',  a.carModel),
            _Row(Icons.pin,            'Номер',       a.carNumber),
          ]),
          const SizedBox(height: 12),

          _Section(title: 'Дата и время', children: [
            _Row(Icons.calendar_today, 'Дата',
                DateFormat('d MMMM yyyy', 'ru').format(a.dateTime)),
            _Row(Icons.access_time, 'Время',
                DateFormat('HH:mm', 'ru').format(a.dateTime)),
          ]),
          const SizedBox(height: 12),

          _Section(title: 'Тип мойки', children: [
            _Row(Icons.local_car_wash, 'Пакет', a.washType.displayName),
            _Row(Icons.payments, 'Итого', '${a.totalPrice} ₽'),
          ]),
          const SizedBox(height: 12),

          if (a.additionalServices.isNotEmpty) ...[ 
            _SectionTitle('Дополнительные услуги'),
            Container(
              decoration: AppStyles.cardDecoration,
              padding: AppStyles.cardPadding,
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: a.additionalServices.map((s) => Chip(
                  label: Text(s, style: const TextStyle(fontSize: 13)),
                  backgroundColor: AppStyles.primary.withOpacity(0.1),
                  side: BorderSide(color: AppStyles.primary.withOpacity(0.3)),
                )).toList(),
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

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.edit),
              label: const Text('Редактировать запись'),
              style: AppStyles.primaryButton,
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => AddEditAppointmentScreen(appointment: a))),
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
              provider.deleteAppointment(id);
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(AppStyles.statusIcon(status), color: color, size: 28),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Статус записи', style: AppStyles.label),
          Text(AppStyles.statusLabel(status),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
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
      child: Column(children: children.map((c) {
        final i = children.indexOf(c);
        return Column(children: [
          c,
          if (i < children.length - 1)
            const Divider(height: 1, indent: 16, endIndent: 16,
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
      Expanded(child: Text(value,
          style: AppStyles.bodyLarge.copyWith(fontWeight: FontWeight.w500),
          textAlign: TextAlign.right)),
    ]),
  );
}
