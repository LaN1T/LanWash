import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/service.dart';

class WasherAppointmentDetailScreen extends StatelessWidget {
  final Appointment appointment;
  const WasherAppointmentDetailScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final auth = context.read<AuthProvider>();
    final services = provider.services;
    
    // Получаем актуальные данные из провайдера
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
        title: const Text('Детали записи (Мойщик)', style: TextStyle(fontSize: 18)),
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
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Статус', style: AppStyles.bodySmall),
                      Text(AppStyles.statusLabel(a.status), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                    ]),
                  ),
                ]),
              ),
            ]),
          ),

          // Смена статуса
          if (a.status != 'cancelled' && a.status != 'completed')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Изменить статус', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppStyles.textSecondary)),
                const SizedBox(height: 8),
                _StatusDropdown(
                  currentStatus: a.status,
                  onChanged: (newStatus) async {
                    final success = await provider.updateAppointment(a.copyWith(status: newStatus), auth);
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Статус изменен на: ${AppStyles.statusLabel(newStatus)}'), backgroundColor: AppStyles.success),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          _InfoTile(Icons.calendar_today_rounded, 'Дата', DateFormat('d MMMM yyyy', 'ru').format(a.dateTime)),
          _InfoTile(Icons.access_time_rounded, 'Время', timeStr),
          _InfoTile(Icons.person_rounded, 'Клиент', a.clientName),
          _InfoTile(Icons.directions_car_rounded, 'Автомобиль', '${a.carModel} · ${a.carNumber}'),
          _InfoTile(Icons.local_car_wash_rounded, 'Услуга', provider.washTypeName(a.washTypeId)),
          _InfoTile(Icons.layers_rounded, 'Бокс', 'Бокс №${a.box_index + 1}'),
          _InfoTile(Icons.payments_rounded, 'Итого', '${a.priceChanged ? a.paidPrice : a.calculateTotalPrice(services, washType)} ₽'),
          
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
          ],

          if (a.notes.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Заметки', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: AppStyles.cardDecoration,
              child: Text(a.notes, style: AppStyles.bodyLarge),
            ),
          ],
          
          const SizedBox(height: 40),
        ]),
      ),
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  final String currentStatus;
  final ValueChanged<String> onChanged;

  const _StatusDropdown({required this.currentStatus, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final List<String> availableOptions;
    if (currentStatus == 'scheduled') {
      availableOptions = ['scheduled', 'in_progress', 'completed'];
    } else if (currentStatus == 'in_progress') {
      availableOptions = ['in_progress', 'completed'];
    } else {
      availableOptions = [currentStatus];
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentStatus,
          isExpanded: true,
          borderRadius: BorderRadius.circular(12),
          items: availableOptions.map((s) => DropdownMenuItem(
            value: s,
            child: Row(
              children: [
                Icon(AppStyles.statusIcon(s), color: AppStyles.statusColor(s), size: 20),
                const SizedBox(width: 12),
                Text(AppStyles.statusLabel(s), style: TextStyle(
                  color: AppStyles.statusColor(s),
                  fontWeight: FontWeight.w600,
                )),
              ],
            ),
          )).toList(),
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
