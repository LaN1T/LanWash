import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../models/service.dart';
import '../../widgets/admin/admin_card.dart';
import '../../widgets/admin/admin_list_tile.dart';
import '../../widgets/admin/admin_section_title.dart';
import '../../widgets/admin/service_list_item.dart';
import '../../widgets/admin/status_badge.dart';
import 'add_edit_appointment_screen.dart';

class AppointmentDetailScreen extends StatelessWidget {
  final Appointment appointment;
  const AppointmentDetailScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final catalogProvider = context.watch<CatalogProvider>();
    final auth = context.watch<AuthProvider>();
    final a = appointmentProvider.appointments.firstWhere(
      (x) => x.id == appointment.id,
      orElse: () => appointment,
    );

    final bool canEdit = !auth.isWasher;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Детали записи',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppStyles.adaptiveBorder(context),
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(a.isFavorite ? Icons.star : Icons.star_border,
                color: a.isFavorite ? AppStyles.favorite : null),
            onPressed: () =>
                appointmentProvider.toggleAppointmentFavorite(a.id),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppStyles.pagePadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          StatusBadge(status: a.status),
          const SizedBox(height: 24),
          if (a.lateMinutes > 0) ...[
            AdminCard(
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppStyles.warning, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Клиент опаздывает на ${a.lateMinutes} мин',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (a.status == 'cancelled' && a.cancelReason.isNotEmpty) ...[
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Причина отмены',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.danger,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    a.cancelReason,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppStyles.adaptiveTextPrimary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (auth.isWasher &&
              (a.status == 'scheduled' || a.status == 'in_progress')) ...[
            const AdminSectionTitle(title: 'Управление статусом'),
            AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: _StatusSelector(
                currentStatus: a.status,
                onChanged: (newStatus) async {
                  final success = await appointmentProvider.updateAppointment(
                      a.copyWith(status: newStatus), auth);
                  if (success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Статус обновлен на: ${AppStyles.statusLabel(newStatus)}')));
                  }
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
          const AdminSectionTitle(title: 'Клиент и автомобиль'),
          AdminCard(
            child: Column(
              children: [
                AdminListTile(
                    icon: Icons.person_outline,
                    title: a.clientName,
                    subtitle: 'Клиент'),
                const Divider(height: 1, indent: 48),
                AdminListTile(
                    icon: Icons.directions_car_outlined,
                    title: a.carModel,
                    subtitle: 'Автомобиль'),
                const Divider(height: 1, indent: 48),
                AdminListTile(
                    icon: Icons.pin_outlined,
                    title: a.carNumber,
                    subtitle: 'Номер'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const AdminSectionTitle(title: 'Дата и время'),
          AdminCard(
            child: Column(
              children: [
                AdminListTile(
                  icon: Icons.calendar_today_outlined,
                  title: DateFormat('d MMMM yyyy', 'ru').format(a.dateTime),
                  subtitle: 'Дата',
                ),
                const Divider(height: 1, indent: 48),
                AdminListTile(
                  icon: Icons.access_time_outlined,
                  title: _formatTimeRange(context, a),
                  subtitle: 'Время',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const AdminSectionTitle(title: 'Услуги'),
          AdminCard(
            child: Column(
              children: [
                ServiceListItem(
                  name: catalogProvider.washTypeName(a.washTypeId),
                  subtitle: 'Тип мойки',
                  priceText:
                      '${a.calculateTotalPrice(catalogProvider.services, catalogProvider.washTypeById(a.washTypeId))} ₽',
                ),
                if (a.additionalServices.isNotEmpty) ...[
                  const Divider(height: 1),
                  ...a.additionalServices.map((id) {
                    final service = catalogProvider.services.firstWhere(
                      (s) => s.id == id,
                      orElse: () => _fallbackService(id),
                    );
                    return ServiceListItem(
                      name: service.name,
                      priceText: '+${service.price} ₽',
                    );
                  }),
                ],
                const Divider(height: 1),
                ServiceListItem(
                  name: 'Итого',
                  priceText: '${a.paidPrice} ₽',
                  isTotal: true,
                ),
                if (a.priceChanged)
                  ServiceListItem(
                    name: 'Было',
                    priceText: '${a.originalPrice} ₽',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (a.notes.isNotEmpty) ...[
            const AdminSectionTitle(title: 'Заметки'),
            AdminCard(
                child:
                    Text(a.notes, style: AppStyles.adaptiveBodyLarge(context))),
            const SizedBox(height: 24),
          ],
          if (canEdit) ...[
            AdminCard(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Редактировать запись'),
                      style: AppStyles.primaryButton,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AddEditAppointmentScreen(appointment: a),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.delete_outline,
                          color: AppStyles.danger),
                      label: const Text('Удалить запись',
                          style: TextStyle(color: AppStyles.danger)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppStyles.danger),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () =>
                          _confirmDelete(context, appointmentProvider, a.id),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ]),
      ),
    );
  }

  void _confirmDelete(BuildContext context,
      AppointmentProvider appointmentProvider, String id) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppStyles.adaptiveCard(context),
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
            onPressed: () async {
              final auth = context.read<AuthProvider>();
              Navigator.pop(context); // закрыть диалог
              try {
                final ok =
                    await appointmentProvider.deleteAppointment(id, auth);
                if (ok && context.mounted) {
                  Navigator.pop(context); // вернуться в список
                }
              } catch (_) {
                // deletion failed; keep the user on the detail screen
              }
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Service _fallbackService(String id) => Service(
        id: id,
        name: id,
        description: '',
        price: 0,
        durationMinutes: 0,
        category: '',
        isFavorite: false,
        isFromApi: false,
      );

  String _formatTimeRange(BuildContext context, Appointment a) {
    final catalogProvider = context.read<CatalogProvider>();
    final washType = catalogProvider.washTypeById(a.washTypeId);
    final duration = (washType?.durationMinutes ?? 30) +
        a.additionalServices
            .where((id) => !(washType?.includedExtraIds.contains(id) ?? false))
            .fold(
                0,
                (sum, id) =>
                    sum +
                    (catalogProvider.services
                        .firstWhere((s) => s.id == id,
                            orElse: () => _fallbackService(id))
                        .durationMinutes));
    final endTime = a.dateTime.add(Duration(minutes: duration.toInt()));
    final cutoff =
        DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day, 22, 0);
    if (endTime.isAfter(cutoff)) {
      final overflow = endTime.difference(cutoff).inMinutes;
      return '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — 22:00, Завтра до ${((8 * 60 + overflow) ~/ 60).toString().padLeft(2, '0')}:${((8 * 60 + overflow) % 60).toString().padLeft(2, '0')}';
    }
    return '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — ${DateFormat('HH:mm', 'ru').format(endTime)}';
  }
}

class _StatusSelector extends StatelessWidget {
  final String currentStatus;
  final ValueChanged<String> onChanged;

  const _StatusSelector({required this.currentStatus, required this.onChanged});

  @override
  Widget build(BuildContext context) {
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
