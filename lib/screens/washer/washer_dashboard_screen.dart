import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/washer/washer_appointment_card.dart';
import '../shared/shift_schedule_screen.dart';
import '../shared/statistics_screen.dart';

class WasherDashboardScreen extends StatelessWidget {
  const WasherDashboardScreen({super.key});

  List<Appointment> _todayAppointments(
    AppointmentProvider provider,
    AuthProvider auth,
  ) {
    final login = auth.userLogin.toLowerCase();
    final now = DateTime.now();
    return provider.appointments.where((a) {
      final assigned = a.assignedWashers.any((w) => w.toLowerCase() == login);
      final sameDay = a.dateTime.year == now.year &&
          a.dateTime.month == now.month &&
          a.dateTime.day == now.day;
      return assigned && sameDay;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appointmentProvider = context.watch<AppointmentProvider>();
    final today = _todayAppointments(appointmentProvider, auth);
    final next = today.isNotEmpty ? today.first : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: RefreshIndicator(
        color: AppStyles.primary,
        onRefresh: () => appointmentProvider.reloadAppointments(auth),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Добрый день, ${auth.username}',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: AppStyles.cardDecorationFor(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Сегодня',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${today.length}',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'запис${today.length == 1 ? 'ь' : (today.length < 5 ? 'и' : 'ей')}',
                                  style: TextStyle(
                                    color: AppStyles.adaptiveTextSecondary(
                                      context,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (next != null)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat('HH:mm', 'ru')
                                        .format(next.dateTime),
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'ближайшая',
                                    style: TextStyle(
                                      color: AppStyles.adaptiveTextSecondary(
                                        context,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ShiftScheduleScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.schedule, size: 18),
                              label: const Text('Расписание'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StatisticsScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.bar_chart, size: 18),
                              label: const Text('Статистика'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
              sliver: today.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          'На сегодня назначений нет',
                          style: TextStyle(
                            color: AppStyles.adaptiveTextSecondary(context),
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => WasherAppointmentCard(
                          appointment: today[index],
                        ),
                        childCount: today.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
