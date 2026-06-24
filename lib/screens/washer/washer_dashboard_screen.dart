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

class WasherDashboardScreen extends StatefulWidget {
  final bool showAppBar;
  final bool wrapWithScaffold;

  const WasherDashboardScreen({
    super.key,
    this.showAppBar = true,
    this.wrapWithScaffold = true,
  });

  @override
  State<WasherDashboardScreen> createState() => _WasherDashboardScreenState();
}

class _WasherDashboardScreenState extends State<WasherDashboardScreen> {
  DateTime _selectedDay = DateTime.now();
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 500000);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Appointment> _workAppointments(
    AppointmentProvider provider,
    AuthProvider auth,
  ) {
    // Backend already returns only appointments assigned to or falling inside
    // this washer's shifts, so we can trust the provider list as-is.
    return provider.appointments.toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final appointmentProvider = context.watch<AppointmentProvider>();
    final now = DateTime.now();

    final all = _workAppointments(appointmentProvider, auth)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final todayAppointments =
        all.where((a) => _isSameDay(a.dateTime, now)).toList();
    final selectedDayAppointments =
        all.where((a) => _isSameDay(a.dateTime, _selectedDay)).toList();
    final next = todayAppointments.isNotEmpty ? todayAppointments.first : null;

    final body = RefreshIndicator(
      color: AppStyles.primary,
      onRefresh: () => appointmentProvider.reloadAppointments(auth),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        children: [
          Text(
            'Добрый день, ${auth.username}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppStyles.adaptiveTextPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(context, todayAppointments, next),
          const SizedBox(height: 16),
          _buildWeekCalendar(context, all),
          const SizedBox(height: 16),
          _buildDayList(context, selectedDayAppointments),
        ],
      ),
    );

    if (!widget.wrapWithScaffold) return body;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: widget.showAppBar
          ? AppBar(
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              title: const Text(
                'Мой день',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: body,
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    List<Appointment> today,
    Appointment? next,
  ) {
    return Container(
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
                        color: AppStyles.adaptiveTextSecondary(context),
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
                        DateFormat('HH:mm', 'ru').format(next.dateTime),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ближайшая',
                        style: TextStyle(
                          color: AppStyles.adaptiveTextSecondary(context),
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
    );
  }

  Widget _buildWeekCalendar(BuildContext context, List<Appointment> all) {
    return Container(
      height: 88,
      decoration: AppStyles.cardDecorationFor(context),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: PageView.builder(
        controller: _pageController,
        itemCount: 1000000,
        itemBuilder: (ctx, pageIndex) {
          final now = DateTime.now();
          final currentWeekStart =
              now.subtract(Duration(days: now.weekday - 1));
          final startOfWeek =
              currentWeekStart.add(Duration(days: (pageIndex - 500000) * 7));
          return Row(
            children: List.generate(7, (i) {
              final d = startOfWeek.add(Duration(days: i));
              final count = all.where((a) => _isSameDay(a.dateTime, d)).length;
              final isSelected = _isSameDay(d, _selectedDay);
              final isToday = _isSameDay(d, now);
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedDay = d),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            isSelected ? AppStyles.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppStyles.primary
                              : (isToday
                                  ? AppStyles.primary
                                  : AppStyles.adaptiveBorder(context)),
                          width: isToday ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            DateFormat('E', 'ru').format(d).toUpperCase(),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppStyles.adaptiveTextSecondary(context),
                              fontSize: 9,
                            ),
                          ),
                          Text(
                            '${d.day}',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppStyles.adaptiveTextPrimary(context),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (count > 0)
                            Container(
                              width: 14,
                              height: 14,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : AppStyles.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '$count',
                                style: TextStyle(
                                  color: isSelected
                                      ? AppStyles.primary
                                      : Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }

  Widget _buildDayList(BuildContext context, List<Appointment> items) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32),
        alignment: Alignment.center,
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
              'На выбранный день записей нет',
              style: AppStyles.headingMedium.copyWith(
                color: AppStyles.adaptiveTextSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: items
          .map((a) => WasherAppointmentCard(appointment: a, readOnly: false))
          .toList(),
    );
  }
}
