import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../models/service.dart';
import '../../providers/catalog_provider.dart';
import '../../screens/shared/appointment_detail_widget.dart';

class WasherAppointmentCard extends StatelessWidget {
  final Appointment appointment;
  const WasherAppointmentCard({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final statusColor = AppStyles.statusColor(a.status);
    final catalogProvider = context.watch<CatalogProvider>();
    final washType = catalogProvider.washTypeById(a.washTypeId);
    final extras = a.additionalServices
        .where((id) => !(washType?.includedExtraIds.contains(id) ?? false));
    final duration = (washType?.durationMinutes ?? 30) +
        extras.fold(
            0,
            (sum, id) =>
                sum +
                (catalogProvider.services
                    .firstWhere((s) => s.id == id,
                        orElse: () => Service(
                            id: id,
                            name: id,
                            description: '',
                            price: 0,
                            durationMinutes: 0,
                            category: ''))
                    .durationMinutes));
    final endTime = a.dateTime.add(Duration(minutes: duration.toInt()));
    final cutoff =
        DateTime(a.dateTime.year, a.dateTime.month, a.dateTime.day, 22, 0);
    String timeStr;
    if (endTime.isAfter(cutoff)) {
      final overflow = endTime.difference(cutoff).inMinutes;
      timeStr =
          '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — 22:00, ⚠ Завтра до ${((8 * 60 + overflow) ~/ 60).toString().padLeft(2, '0')}:${((8 * 60 + overflow) % 60).toString().padLeft(2, '0')}';
    } else {
      timeStr =
          '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — ${DateFormat('HH:mm', 'ru').format(endTime)}';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppStyles.adaptiveCard(context),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppStyles.adaptiveBorder(context))),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) =>
              AppointmentDetailWidget(appointment: a, isClient: false),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    Icon(AppStyles.statusIcon(a.status),
                        size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(AppStyles.statusLabel(a.status),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusColor)),
                  ]),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppStyles.adaptivePrimaryBg(context),
                      borderRadius: BorderRadius.circular(6)),
                  child: Text(timeStr,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primary)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.person,
                    size: 16, color: AppStyles.adaptiveTextSecondary(context)),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(a.clientName,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppStyles.adaptiveTextPrimary(context)))),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.directions_car,
                    size: 16, color: AppStyles.adaptiveTextSecondary(context)),
                const SizedBox(width: 6),
                Text(a.carModel,
                    style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.adaptiveTextSecondary(context))),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: AppStyles.adaptivePrimaryBg(context),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('Бокс №${a.box_index + 1}',
                      style: const TextStyle(
                          color: AppStyles.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
