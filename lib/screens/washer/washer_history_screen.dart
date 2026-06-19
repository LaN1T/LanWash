import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../widgets/washer/washer_appointment_card.dart';

class WasherHistoryScreen extends StatelessWidget {
  const WasherHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = context.select<AppointmentProvider, List<Appointment>>(
      (p) => p.appointments
          .where((a) => a.status == 'completed' || a.status == 'cancelled')
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('История')),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history,
                      size: 56,
                      color: AppStyles.adaptiveTextSecondary(context)
                          .withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('Нет завершённых или отменённых записей',
                      style: AppStyles.headingMedium.copyWith(
                          color: AppStyles.adaptiveTextSecondary(context))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (_, i) =>
                  WasherAppointmentCard(appointment: items[i]),
            ),
    );
  }
}
