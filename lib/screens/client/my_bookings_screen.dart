import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../models/service.dart';
import '../shared/appointment_detail_widget.dart';
import 'booking_wizard_screen.dart';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});
  @override
  State<MyBookingsScreen> createState() => _State();
}

class _State extends State<MyBookingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppointmentProvider>().clearDeletedByAdminFlag();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final catalogProvider = context.watch<CatalogProvider>();
    final auth = context.watch<AuthProvider>();
    final username = auth.userLogin.toLowerCase();

    final all = auth.isAdmin
        ? appointmentProvider.appointments
        : appointmentProvider.appointments
            .where((a) =>
                a.ownerUsername.toLowerCase() == username ||
                (a.ownerUsername.isEmpty &&
                    a.clientName.toLowerCase() == username))
            .toList();

    final upcoming = all
        .where((a) => a.status == 'scheduled' || a.status == 'in_progress')
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    final history = all
        .where((a) => a.status == 'completed' || a.status == 'cancelled')
        .toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Column(children: [
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
          child: TabBarView(controller: _tab, children: [
        _BookingsList(items: upcoming, services: catalogProvider.services),
        _BookingsList(items: history, services: catalogProvider.services, showBookAgain: true),
      ])),
    ]);
  }
}

class _BookingsList extends StatelessWidget {
  final List<Appointment> items;
  final List<dynamic> services;
  final bool showBookAgain;
  const _BookingsList({required this.items, required this.services, this.showBookAgain = false});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppStyles.primary,
      onRefresh: () => context
          .read<AppointmentProvider>()
          .reloadAppointments(context.read<AuthProvider>()),
      child: ListView.builder(
        padding: AppStyles.pagePadding,
        itemCount: items.length,
        itemBuilder: (ctx, i) {
          final a = items[i];
          final color = AppStyles.statusColor(a.status);
          final bgColor = AppStyles.statusBgColor(a.status);
          final catalogProvider = context.watch<CatalogProvider>();

          return GestureDetector(
            onTap: () {
              ctx.read<AppointmentProvider>().markAsSeen(a.id);
              if (a.isModifiedByAdmin || a.isModifiedByWasher) {
                ctx.read<AppointmentProvider>().clearModifiedFlag(a.id);
              }
              _showDetail(ctx, a, catalogProvider.services);
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppStyles.cardDecorationFor(context),
              padding: const EdgeInsets.all(16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(10)),
                        child: Icon(AppStyles.statusIcon(a.status),
                            color: color, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(catalogProvider.washTypeName(a.washTypeId),
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.adaptiveTextPrimary(
                                        context))),
                            Row(children: [
                              Text('${a.carModel} · ${a.carNumber}',
                                  style: AppStyles.bodySmall.copyWith(
                                      color: AppStyles.adaptiveTextSecondary(
                                          context))),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                    color: AppStyles.adaptivePrimaryBg(context),
                                    borderRadius: BorderRadius.circular(4)),
                                child: Text('Бокс №${a.box_index + 1}',
                                    style: const TextStyle(
                                        color: AppStyles.primary,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ]),
                          ])),
                      if ((a.isModifiedByAdmin || a.isModifiedByWasher) &&
                          !a.isSeenByClient)
                        const Icon(Icons.error,
                            color: AppStyles.danger, size: 20),
                    ]),
                    const SizedBox(height: 12),
                    Container(
                        height: 1, color: AppStyles.adaptiveBorder(context)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(Icons.access_time_rounded,
                          size: 14,
                          color: AppStyles.adaptiveTextSecondary(context)),
                      const SizedBox(width: 4),
                      Builder(builder: (context) {
                        final washType =
                            catalogProvider.washTypeById(a.washTypeId);
                        final duration = a.calculateTotalPrice(
                                    services.cast<Service>(), washType) >=
                                0
                            ? (washType?.durationMinutes ?? 30) +
                                a.additionalServices
                                    .where((id) => !(washType?.includedExtraIds
                                            .contains(id) ??
                                        false))
                                    .fold(
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
                                                        category: '',
                                                        isFavorite: false,
                                                        isFromApi: false))
                                                .durationMinutes))
                            : 30;
                        final endTime =
                            a.dateTime.add(Duration(minutes: duration.toInt()));
                        final cutoff = DateTime(a.dateTime.year,
                            a.dateTime.month, a.dateTime.day, 22, 0);
                        String timeStr;
                        if (endTime.isAfter(cutoff)) {
                          final overflow = endTime.difference(cutoff).inMinutes;
                          timeStr =
                              '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — 22:00, ⚠ Завтра до ${((8 * 60 + overflow) ~/ 60).toString().padLeft(2, '0')}:${((8 * 60 + overflow) % 60).toString().padLeft(2, '0')}';
                        } else {
                          timeStr =
                              '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — ${DateFormat('HH:mm').format(endTime)}';
                        }
                        return Text(timeStr,
                            style: TextStyle(
                                color: AppStyles.adaptiveTextPrimary(context),
                                fontSize: 13,
                                fontWeight: FontWeight.w500));
                      }),
                      const Spacer(),
                      Text(
                          '${a.calculateTotalPrice(services.cast<Service>(), catalogProvider.washTypeById(a.washTypeId))} ₽',
                          style: const TextStyle(
                              color: AppStyles.primary,
                              fontSize: 15,
                              fontWeight: FontWeight.bold)),
                    ]),
                    if (showBookAgain) ...[
                      const SizedBox(height: 12),
                      Container(
                          height: 1, color: AppStyles.adaptiveBorder(context)),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (_) => BookingWizardScreen(templateAppointment: a),
                            ));
                          },
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Записаться снова'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppStyles.primary,
                            side: const BorderSide(color: AppStyles.primary),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                    ],
                  ]),
            ),
          );
        },
      ),
    );
  }

  void _showDetail(
      BuildContext context, Appointment a, List<dynamic> services) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppointmentDetailWidget(appointment: a),
    );
  }
}

Widget _detailRow(IconData icon, String label, String value) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Icon(icon, size: 18, color: AppStyles.primary),
        const SizedBox(width: 10),
        Text(label, style: AppStyles.bodyMedium),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
      ]),
    );
