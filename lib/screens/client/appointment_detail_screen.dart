import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/service.dart';

class ClientAppointmentDetailScreen extends StatelessWidget {
  final Appointment appointment;
  const ClientAppointmentDetailScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final auth = context.read<AuthProvider>();
    final services = provider.services;
    final a = provider.appointments.firstWhere(
      (x) => x.id == appointment.id, orElse: () => appointment,
    );
    final washType = provider.washTypeById(a.washTypeId);
    
    // Расчет длительности
    final duration = a.calculateTotalPrice(services.cast<Service>(), washType) >= 0 
        ? (washType?.durationMinutes ?? 30) + 
          a.additionalServices.where((id) => !(washType?.includedExtraIds.contains(id) ?? false)).fold(0, (sum, id) => sum + (provider.services.firstWhere((s) => s.id == id, orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: '', isFavorite: false, isFromApi: false)).durationMinutes))
        : 30;
    final endTime = a.dateTime.add(Duration(minutes: duration.toInt()));
    final timeStr = '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — ${DateFormat('HH:mm', 'ru').format(endTime)}';

    final color = AppStyles.statusColor(a.status);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Детали записи', style: TextStyle(fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppStyles.textPrimary,
      ),
      body: SingleChildScrollView(
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(children: [
                  Icon(AppStyles.statusIcon(a.status), color: color, size: 32),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Статус', style: AppStyles.bodySmall),
                    Text(AppStyles.statusLabel(a.status), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                  ]),
                ]),
              ),
            ]),
          ),
          
          _InfoTile(Icons.calendar_today_rounded, 'Дата', DateFormat('d MMMM yyyy', 'ru').format(a.dateTime)),
          _InfoTile(Icons.access_time_rounded, 'Время', timeStr),
          _InfoTile(Icons.directions_car_rounded, 'Автомобиль', '${a.carModel} · ${a.carNumber}'),
          _InfoTile(Icons.local_car_wash_rounded, 'Услуга', provider.washTypeName(a.washTypeId)),
          _InfoTile(Icons.layers_rounded, 'Бокс', 'Бокс №${a.box_index + 1}'),
          _InfoTile(Icons.payments_rounded, 'Итого', '${a.calculateTotalPrice(services, washType)} ₽'),
          
          if (a.additionalServices.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('Дополнительные услуги', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: AppStyles.cardDecoration,
              child: Column(
                children: a.additionalServices.map((id) {
                  final svc = services.firstWhere((s) => s.id == id, orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: '', isFavorite: false, isFromApi: false));
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(children: [
                      const Icon(Icons.add_circle_outline, size: 18, color: AppStyles.primary),
                      const SizedBox(width: 12),
                      Text(svc.name, style: const TextStyle(fontSize: 14)),
                      const Spacer(),
                      Text('${svc.price} ₽', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    ]),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),
          ],

          if (a.status == 'scheduled')
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmCancel(context, provider, auth, a.id),
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Отменить запись', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppStyles.danger,
                    side: const BorderSide(color: AppStyles.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  void _confirmCancel(BuildContext context, AppProvider provider, AuthProvider auth, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Отменить запись?'),
        content: const Text('Это действие нельзя будет отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Назад')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await provider.cancelAppointment(id, auth);
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Запись отменена'), backgroundColor: AppStyles.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppStyles.danger, foregroundColor: Colors.white),
            child: const Text('Отменить'),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    child: Row(children: [
      Icon(icon, size: 22, color: AppStyles.primary),
      const SizedBox(width: 16),
      Text(label, style: const TextStyle(color: AppStyles.textSecondary, fontSize: 15)),
      const Spacer(),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
    ]),
  );
}
