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
    final auth = context.watch<AuthProvider>();
    final isWasher = auth.isWasher;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Детали записи', style: AppStyles.headingMedium),
            ],
          ),
          const SizedBox(height: 16),
          
          _StatusBanner(status: a.status),
          const SizedBox(height: 16),

          if (isWasher && a.status != 'cancelled' && a.status != 'completed') ...[
            const Text('Изменить статус', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppStyles.textSecondary)),
            const SizedBox(height: 8),
            _StatusSelector(
              currentStatus: a.status,
              onChanged: (newStatus) async {
                final success = await provider.updateAppointment(a.copyWith(status: newStatus, isModifiedByWasher: true), auth);
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Статус обновлен: ${AppStyles.statusLabel(newStatus)}'), backgroundColor: AppStyles.success),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
          ],
          
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

          _Row(Icons.person, 'Клиент', a.clientName),
          _Row(Icons.directions_car, 'Автомобиль', a.carModel),
          _Row(Icons.pin, 'Номер', a.carNumber),
          _Row(Icons.local_car_wash, 'Услуга', provider.washTypeName(a.washTypeId)),
          _Row(Icons.layers_rounded, 'Бокс', 'Бокс №${a.box_index + 1}'),
          _Row(Icons.payments, 'Итого', '${a.priceChanged ? a.paidPrice : a.calculateTotalPrice(provider.services, provider.washTypeById(a.washTypeId))} ₽'),
          
          if (a.additionalServices.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showAdditionalServices(context, provider, a.additionalServices),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppStyles.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppStyles.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt, size: 20, color: AppStyles.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Доп. услуги (${a.additionalServices.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: AppStyles.primary))),
                    const Icon(Icons.chevron_right, color: AppStyles.primary),
                  ],
                ),
              ),
            ),
          ],

          if (a.notes.isNotEmpty && isWasher) ...[
            const SizedBox(height: 12),
            const Text('Заметки', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppStyles.textSecondary)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.bgMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(a.notes, style: AppStyles.bodyMedium),
            ),
          ],

          const SizedBox(height: 24),
          
          if (auth.isClient && a.status == 'scheduled')
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

  void _showAdditionalServices(BuildContext context, AppProvider provider, List<String> additionalServiceIds) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Дополнительные услуги', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: additionalServiceIds.length,
                itemBuilder: (context, index) {
                  final id = additionalServiceIds[index];
                  final service = provider.services.firstWhere((s) => s.id == id, orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: ''));
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppStyles.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(child: Text(service.name, style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppStyles.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
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

class _StatusSelector extends StatelessWidget {
  final String currentStatus;
  final ValueChanged<String> onChanged;

  const _StatusSelector({required this.currentStatus, required this.onChanged});

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
          icon: const Icon(Icons.arrow_drop_down_circle_outlined, color: AppStyles.primary),
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
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Смена статуса'),
                  content: Text('Вы действительно хотите изменить статус на "${AppStyles.statusLabel(v)}"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppStyles.primary, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        onChanged(v);
                      },
                      child: const Text('Да'),
                    ),
                  ],
                ),
              );
            }
          },
        ),
      ),
    );
  }
}
