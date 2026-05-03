import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/service.dart';
import '../add_edit_appointment_screen.dart';

class AppointmentDetailWidget extends StatelessWidget {
  final Appointment appointment;
  final bool isClient;

  const AppointmentDetailWidget({
    super.key,
    required this.appointment,
    this.isClient = true,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final a = provider.appointments.firstWhere(
      (x) => x.id == appointment.id, orElse: () => appointment,
    );

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppStyles.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Детали записи', style: AppStyles.headingMedium),
          const SizedBox(height: 16),
          
          _StatusBanner(status: a.status),
          const SizedBox(height: 16),
          
          _Row(Icons.calendar_today, 'Дата', DateFormat('d MMMM yyyy', 'ru').format(a.dateTime)),
          
          Builder(builder: (context) {
            final washType = provider.washTypeById(a.washTypeId);
            final duration = a.calculateTotalPrice(provider.services, washType) >= 0 
                ? (washType?.durationMinutes ?? 30) + 
                  a.additionalServices.where((id) => !(washType?.includedExtraIds.contains(id) ?? false)).fold(0, (sum, id) => sum + (provider.services.firstWhere((s) => s.id == id, orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: '', isFavorite: false, isFromApi: false)).durationMinutes))
                : 30;
            final endTime = a.dateTime.add(Duration(minutes: duration.toInt()));
            final cutoff = DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day, 22, 0);
            String timeStr = endTime.isAfter(cutoff) 
                ? '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — 22:00, ⚠ Завтра до ${((8 * 60 + (endTime.difference(cutoff).inMinutes)) ~/ 60).toString().padLeft(2, '0')}:${((8 * 60 + (endTime.difference(cutoff).inMinutes)) % 60).toString().padLeft(2, '0')}'
                : '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — ${DateFormat('HH:mm').format(endTime)}';
            return _Row(Icons.access_time, 'Время', timeStr);
          }),

          _Row(Icons.directions_car, 'Автомобиль', a.carModel),
          _Row(Icons.pin, 'Номер', a.carNumber),
          _Row(Icons.local_car_wash, 'Услуга', provider.washTypeName(a.washTypeId)),
          _Row(Icons.payments, 'Итого', '${a.priceChanged ? a.paidPrice : a.calculateTotalPrice(provider.services, provider.washTypeById(a.washTypeId))} ₽'),
          
          const SizedBox(height: 24),
          
          if (isClient)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline, color: AppStyles.danger),
                label: const Text('Отменить запись', style: TextStyle(color: AppStyles.danger)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppStyles.danger),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  _confirmDelete(context, provider, a.id);
                },
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppProvider provider, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Отменить запись?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppStyles.danger, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              final auth = context.read<AuthProvider>();
              provider.deleteAppointment(id, auth);
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Icon(AppStyles.statusIcon(status), color: color, size: 24),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Статус', style: TextStyle(fontSize: 12, color: AppStyles.textSecondary)),
          Text(AppStyles.statusLabel(status), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ]),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Icon(icon, size: 18, color: AppStyles.textSecondary),
      const SizedBox(width: 12),
      Text(label, style: const TextStyle(color: AppStyles.textSecondary, fontSize: 14)),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
    ]),
  );
}
