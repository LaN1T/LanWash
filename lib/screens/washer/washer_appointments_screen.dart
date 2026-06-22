import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/washer/washer_appointment_card.dart';

class WasherAppointmentsScreen extends StatefulWidget {
  const WasherAppointmentsScreen({super.key});

  @override
  State<WasherAppointmentsScreen> createState() => _State();
}

class _State extends State<WasherAppointmentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<Appointment> _filtered(
    AppointmentProvider provider,
    AuthProvider auth,
  ) {
    final login = auth.userLogin.toLowerCase();
    return provider.appointments
        .where((a) => a.assignedWashers.any((w) => w.toLowerCase() == login))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final auth = context.watch<AuthProvider>();

    final all = _filtered(appointmentProvider, auth)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final upcoming = all
        .where((a) => a.status == 'scheduled' || a.status == 'in_progress')
        .toList();
    final history = all
        .where((a) => a.status == 'completed' || a.status == 'cancelled')
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Column(
      children: [
        Container(
          color: AppStyles.adaptiveCard(context),
          child: TabBar(
            controller: _tab,
            labelColor: AppStyles.primary,
            unselectedLabelColor: AppStyles.adaptiveTextSecondary(context),
            indicatorColor: AppStyles.primary,
            tabs: const [Tab(text: 'Активные'), Tab(text: 'История')],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _AppointmentsList(items: upcoming),
              _AppointmentsList(items: history),
            ],
          ),
        ),
      ],
    );
  }
}

class _AppointmentsList extends StatelessWidget {
  final List<Appointment> items;
  const _AppointmentsList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 64,
              color: AppStyles.adaptiveTextSecondary(context)
                  .withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Нет записей',
              style: AppStyles.headingMedium.copyWith(
                color: AppStyles.adaptiveTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppStyles.primary,
      onRefresh: () => context
          .read<AppointmentProvider>()
          .reloadAppointments(context.read<AuthProvider>()),
      child: ListView.builder(
        padding: AppStyles.pagePadding,
        itemCount: items.length,
        itemBuilder: (_, i) => WasherAppointmentCard(appointment: items[i]),
      ),
    );
  }
}
