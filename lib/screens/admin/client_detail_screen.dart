import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../models/car.dart';
import '../../models/service.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import 'package:lanwash/core/service_locator.dart';

class ClientDetailScreen extends StatefulWidget {
  final User user;

  const ClientDetailScreen({super.key, required this.user});

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  bool _loadingCars = true;
  bool _loadingAppointments = true;
  List<Car> _cars = [];
  List<Appointment> _appointments = [];
  Map<String, String> _serviceNames = {};
  String? _carsError;
  String? _appointmentsError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = sl<ApiService>();
    final results = await Future.wait([
      api.getCarsForUser(widget.user.id!).then((list) => _CarsResult(list))
          .catchError((e) => _CarsResult([], e.toString())),
      api.getAppointmentsByOwner(widget.user.username)
          .then((list) => _AppointmentsResult(list))
          .catchError((e) => _AppointmentsResult([], e.toString())),
      api.getServices()
          .then((list) => _ServicesResult(list))
          .catchError((e) => _ServicesResult([], e.toString())),
    ]);

    final carsResult = results[0] as _CarsResult;
    final apptsResult = results[1] as _AppointmentsResult;
    final servicesResult = results[2] as _ServicesResult;

    if (mounted) {
      setState(() {
        _cars = carsResult.cars;
        _carsError = carsResult.error;
        _loadingCars = false;
        _appointments = apptsResult.appointments;
        _appointmentsError = apptsResult.error;
        _loadingAppointments = false;
        _serviceNames = {
          for (final s in servicesResult.services) s.id: s.name,
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final dateFormat = DateFormat('dd.MM.yyyy');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Карточка клиента',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: AppStyles.primary,
                          child: Text(
                            u.displayName.isNotEmpty
                                ? u.displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                u.displayName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyles.adaptiveTextPrimary(context),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '@${u.username}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      AppStyles.adaptiveTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _InfoRow(icon: Icons.phone_outlined, text: u.phone),
                    _InfoRow(
                      icon: Icons.email_outlined,
                      text: u.email.isNotEmpty ? u.email : 'Email не указан',
                    ),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      text: 'Клиент с ${dateFormat.format(u.createdAt)}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const _SectionTitle('Автомобили'),
              const SizedBox(height: 10),
              _buildCars(context),
              const SizedBox(height: 24),
              const _SectionTitle('История записей'),
              const SizedBox(height: 10),
              _buildAppointments(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCars(BuildContext context) {
    if (_loadingCars) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppStyles.primary),
        ),
      );
    }
    if (_carsError != null) {
      return _Placeholder(text: 'Не удалось загрузить авто: $_carsError');
    }
    if (_cars.isEmpty) {
      return const _Placeholder(
        text: 'Автомобили не привязаны',
        icon: Icons.directions_car_outlined,
      );
    }
    return Column(
      children: _cars.map((car) {
        return _SectionCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppStyles.adaptivePrimaryBg(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_car_filled_outlined,
                  color: AppStyles.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.displayName.isNotEmpty
                          ? car.displayName
                          : 'Автомобиль',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.adaptiveTextPrimary(context),
                      ),
                    ),
                    if (car.number.isNotEmpty)
                      Text(
                        car.number,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppStyles.adaptiveTextSecondary(context),
                        ),
                      ),
                  ],
                ),
              ),
              if (car.isPrimary)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppStyles.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Основной',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.success,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAppointments(BuildContext context) {
    if (_loadingAppointments) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(color: AppStyles.primary),
        ),
      );
    }
    if (_appointmentsError != null) {
      return _Placeholder(
        text: 'Не удалось загрузить записи: $_appointmentsError',
      );
    }
    if (_appointments.isEmpty) {
      return const _Placeholder(
        text: 'Пока нет записей',
        icon: Icons.history_outlined,
      );
    }

    final sorted = [..._appointments]
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Column(
      children: sorted.map((appt) {
        return _SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_statusLabel(appt.status)} · ${_dateTimeText(appt.dateTime)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _statusColor(appt.status),
                      ),
                    ),
                  ),
                  if (appt.originalPrice > 0)
                    Text(
                      '${appt.originalPrice} ₽',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.adaptiveTextPrimary(context),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${appt.carModel}${appt.carNumber.isNotEmpty ? ' · ${appt.carNumber}' : ''}',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
              ),
              if (appt.additionalServices.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Доп: ${appt.additionalServices.map((id) => _serviceNames[id] ?? id).join(', ')}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.adaptiveTextMuted(context),
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _dateTimeText(DateTime dt) {
    return DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'scheduled':
        return 'Запланирована';
      case 'in_progress':
        return 'В работе';
      case 'completed':
        return 'Завершена';
      case 'cancelled':
        return 'Отменена';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed':
        return AppStyles.success;
      case 'in_progress':
        return AppStyles.warning;
      case 'cancelled':
        return AppStyles.danger;
      default:
        return AppStyles.primary;
    }
  }
}

class _CarsResult {
  final List<Car> cars;
  final String? error;
  _CarsResult(this.cars, [this.error]);
}

class _AppointmentsResult {
  final List<Appointment> appointments;
  final String? error;
  _AppointmentsResult(this.appointments, [this.error]);
}

class _ServicesResult {
  final List<Service> services;
  final String? error;
  _ServicesResult(this.services, [this.error]);
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppStyles.adaptiveTextPrimary(context),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppStyles.adaptiveTextSecondary(context),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text.isNotEmpty ? text : 'Не указано',
              style: TextStyle(
                fontSize: 14,
                color: AppStyles.adaptiveTextPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Placeholder({required this.text, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppStyles.adaptiveTextSecondary(context)),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppStyles.adaptiveTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
