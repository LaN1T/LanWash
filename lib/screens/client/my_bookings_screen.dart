import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../models/service.dart';
import '../../services/api_service.dart';
import '../shared/appointment_detail_widget.dart';
import 'booking_wizard_screen.dart';
import 'review_create_screen.dart';

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
        _BookingsList(
          items: upcoming,
          services: catalogProvider.services,
          catalogProvider: catalogProvider,
        ),
        _BookingsList(
          items: history,
          services: catalogProvider.services,
          catalogProvider: catalogProvider,
        ),
      ])),
    ]);
  }
}

class _BookingsList extends StatelessWidget {
  final List<Appointment> items;
  final List<dynamic> services;
  final CatalogProvider catalogProvider;
  const _BookingsList({
    required this.items,
    required this.services,
    required this.catalogProvider,
  });

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
          return GestureDetector(
            onTap: () {
              ctx.read<AppointmentProvider>().markAsSeen(a.id);
              if (a.isModifiedByAdmin || a.isModifiedByWasher) {
                ctx.read<AppointmentProvider>().clearModifiedFlag(a.id);
              }
              _showDetail(ctx, a);
            },
            child: _HistoryAppointmentCard(
              a: a,
              services: services,
              catalogProvider: catalogProvider,
            ),
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, Appointment a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppointmentDetailWidget(appointment: a),
    );
  }
}

class _HistoryAppointmentCard extends StatefulWidget {
  final Appointment a;
  final List<dynamic> services;
  final CatalogProvider catalogProvider;
  const _HistoryAppointmentCard({
    required this.a,
    required this.services,
    required this.catalogProvider,
  });

  @override
  State<_HistoryAppointmentCard> createState() =>
      _HistoryAppointmentCardState();
}

class _HistoryAppointmentCardState extends State<_HistoryAppointmentCard> {
  late Future<bool> _reviewFuture;

  @override
  void initState() {
    super.initState();
    if (widget.a.status == 'completed') {
      _reviewFuture =
          context.read<ApiService>().hasReviewForAppointment(widget.a.id);
    } else {
      _reviewFuture = Future.value(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppStyles.statusColor(widget.a.status);
    final bgColor = AppStyles.statusBgColor(widget.a.status);
    final showActions =
        widget.a.status == 'completed' || widget.a.status == 'cancelled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.cardDecorationFor(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopRow(color, bgColor),
          const SizedBox(height: 12),
          Container(height: 1, color: AppStyles.adaptiveBorder(context)),
          const SizedBox(height: 12),
          _buildTimePriceRow(),
          if (showActions) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: AppStyles.adaptiveBorder(context)),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: _buildBottomButton(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTopRow(Color color, Color bgColor) {
    final showRefresh =
        widget.a.status == 'completed' || widget.a.status == 'cancelled';

    return Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: bgColor, borderRadius: BorderRadius.circular(10)),
        child:
            Icon(AppStyles.statusIcon(widget.a.status), color: color, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.catalogProvider.washTypeName(widget.a.washTypeId),
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppStyles.adaptiveTextPrimary(context))),
        Row(children: [
          Text('${widget.a.carModel} · ${widget.a.carNumber}',
              style: AppStyles.bodySmall
                  .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
                color: AppStyles.adaptivePrimaryBg(context),
                borderRadius: BorderRadius.circular(4)),
            child: Text('Бокс №${widget.a.boxIndex + 1}',
                style: const TextStyle(
                    color: AppStyles.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ]),
      ])),
      if ((widget.a.isModifiedByAdmin || widget.a.isModifiedByWasher) &&
          !widget.a.isSeenByClient)
        const Icon(Icons.error, color: AppStyles.danger, size: 20),
      if (showRefresh) ...[
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          tooltip: 'Записаться снова',
          color: AppStyles.primary,
          onPressed: _bookAgain,
        ),
      ],
    ]);
  }

  Widget _buildTimePriceRow() {
    final washType = widget.catalogProvider.washTypeById(widget.a.washTypeId);
    final services = widget.services.cast<Service>();
    final totalPrice = widget.a.calculateTotalPrice(services, washType);
    final duration = washType != null
        ? washType.durationMinutes +
            widget.a.additionalServices
                .where((id) => !washType.includedExtraIds.contains(id))
                .fold<int>(
                    0,
                    (sum, id) =>
                        sum +
                        (widget.catalogProvider.services
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
    final endTime = widget.a.dateTime.add(Duration(minutes: duration));
    final cutoff = DateTime(widget.a.dateTime.year, widget.a.dateTime.month,
        widget.a.dateTime.day, 22, 0);
    String timeStr;
    if (endTime.isAfter(cutoff)) {
      final overflow = endTime.difference(cutoff).inMinutes;
      timeStr =
          '${DateFormat('HH:mm', 'ru').format(widget.a.dateTime)} — 22:00, ⚠ Завтра до ${((8 * 60 + overflow) ~/ 60).toString().padLeft(2, '0')}:${((8 * 60 + overflow) % 60).toString().padLeft(2, '0')}';
    } else {
      timeStr =
          '${DateFormat('HH:mm', 'ru').format(widget.a.dateTime)} — ${DateFormat('HH:mm').format(endTime)}';
    }

    return Row(children: [
      Icon(Icons.access_time_rounded,
          size: 14, color: AppStyles.adaptiveTextSecondary(context)),
      const SizedBox(width: 4),
      Text(timeStr,
          style: TextStyle(
              color: AppStyles.adaptiveTextPrimary(context),
              fontSize: 13,
              fontWeight: FontWeight.w500)),
      const Spacer(),
      Text(
        '$totalPrice ₽',
        style: const TextStyle(
          color: AppStyles.primary,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    ]);
  }

  Widget _buildBottomButton() {
    if (widget.a.status == 'cancelled') {
      return OutlinedButton.icon(
        onPressed: _bookAgain,
        icon: const Icon(Icons.refresh, size: 16),
        label: const Text('Записаться снова'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppStyles.primary,
          side: const BorderSide(color: AppStyles.primary),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      );
    }

    if (widget.a.status == 'completed') {
      return FutureBuilder<bool>(
        future: _reviewFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 36,
              width: 36,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          final hasReview = snapshot.hasData && snapshot.data == true;
          if (hasReview) {
            return OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Отзыв оставлен'),
              style: OutlinedButton.styleFrom(
                disabledForegroundColor:
                    AppStyles.adaptiveTextSecondary(context),
                side: BorderSide(color: AppStyles.adaptiveBorder(context)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            );
          }
          return OutlinedButton.icon(
            onPressed: _openReview,
            icon: const Icon(Icons.rate_review, size: 16),
            label: const Text('Оставить отзыв'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppStyles.primary,
              side: const BorderSide(color: AppStyles.primary),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          );
        },
      );
    }

    return const SizedBox.shrink();
  }

  void _bookAgain() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingWizardScreen(templateAppointment: widget.a),
      ),
    );
  }

  Future<void> _openReview() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewCreateScreen(appointmentId: widget.a.id),
      ),
    );
    if (result == true && mounted) {
      setState(() {
        _reviewFuture =
            context.read<ApiService>().hasReviewForAppointment(widget.a.id);
      });
    }
  }
}
