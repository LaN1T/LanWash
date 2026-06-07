import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../models/service.dart';
import '../../models/user.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';

class AdminScheduleScreen extends StatefulWidget {
  const AdminScheduleScreen({super.key});
  @override
  State<AdminScheduleScreen> createState() => _AdminScheduleScreenState();
}

class _AdminScheduleScreenState extends State<AdminScheduleScreen> {
  late List<DateTime> _days;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _days = List.generate(14, (i) => today.add(Duration(days: i)));
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final appointments = appointmentProvider.appointments;

    return Scaffold(
      backgroundColor: AppStyles.adaptiveBgPage(context),
      appBar: AppBar(
        backgroundColor: AppStyles.adaptiveCard(context),
        foregroundColor: AppStyles.adaptiveTextPrimary(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppStyles.primaryGradient,
            ),
            child:
                const Icon(Icons.calendar_month, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text('Расписание',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.adaptiveTextPrimary(context))),
        ]),
      ),
      body: RefreshIndicator(
        color: AppStyles.primary,
        onRefresh: () => appointmentProvider
            .reloadAppointments(context.read<AuthProvider>()),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 0.8,
            ),
            itemCount: _days.length,
            itemBuilder: (context, index) {
              final day = _days[index];
              final count = _countForDay(appointments, day);
              final isToday = _isToday(day);

              return GestureDetector(
                onTap: () => _openDay(context, day),
                child: Container(
                  decoration: BoxDecoration(
                    color: isToday
                        ? AppStyles.primary.withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isToday
                          ? AppStyles.primary
                          : AppStyles.adaptiveBorder(context),
                      width: isToday ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .shadow
                            .withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      if (count > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                                color: AppStyles.primary,
                                shape: BoxShape.circle),
                            child: Text('$count',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                DateFormat('EE', 'ru')
                                    .format(day)
                                    .toUpperCase(),
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isToday
                                        ? AppStyles.primary
                                        : AppStyles.adaptiveTextSecondary(
                                            context))),
                            Text('${day.day}',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isToday
                                        ? AppStyles.primary
                                        : AppStyles.adaptiveTextPrimary(
                                            context))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  int _countForDay(List<Appointment> appointments, DateTime day) {
    return appointments
        .where((a) =>
            a.dateTime.year == day.year &&
            a.dateTime.month == day.month &&
            a.dateTime.day == day.day)
        .length;
  }

  bool _isToday(DateTime day) {
    final now = DateTime.now();
    return day.year == now.year && day.month == now.month && day.day == now.day;
  }

  void _openDay(BuildContext context, DateTime day) {
    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _DayScheduleScreen(day: day),
        ));
  }
}

// ─── Экран дня: мойщики слева, записи справа ─────────────────────────────────
class _DayScheduleScreen extends StatefulWidget {
  final DateTime day;
  const _DayScheduleScreen({required this.day});

  @override
  State<_DayScheduleScreen> createState() => _DayScheduleScreenState();
}

class _DayScheduleScreenState extends State<_DayScheduleScreen> {
  List<User> _washers = [];
  bool _loading = true;
  String? _selectedWasher;

  @override
  void initState() {
    super.initState();
    _loadWashers();
  }

  Future<void> _loadWashers() async {
    final provider = context.read<AppointmentProvider>();
    final washers = await provider.getWashers();
    if (mounted) {
      setState(() {
        _washers = washers;
        _loading = false;
      });
    }
  }

  List<Appointment> _dayAppointments(AppointmentProvider provider) {
    return provider.appointments
        .where((a) =>
            a.dateTime.year == widget.day.year &&
            a.dateTime.month == widget.day.month &&
            a.dateTime.day == widget.day.day)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  String _washerDisplayName(String username) {
    final w = _washers.where((w) => w.username == username);
    if (w.isNotEmpty) {
      return w.first.displayName.isNotEmpty
          ? w.first.displayName
          : w.first.username;
    }
    return username;
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final catalogProvider = context.watch<CatalogProvider>();
    final dayAppts = _dayAppointments(appointmentProvider);
    final dateStr = DateFormat('d MMMM yyyy, EEEE', 'ru').format(widget.day);

    return Scaffold(
      backgroundColor: AppStyles.adaptiveBgPage(context),
      appBar: AppBar(
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(dateStr,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppStyles.primary))
          : Row(
              children: [
                // Левая панель: мойщики
                SizedBox(
                  width: 160,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppStyles.primary.withValues(alpha: 0.08),
                            border: Border(
                                bottom: BorderSide(
                                    color: AppStyles.adaptiveBorder(context))),
                          ),
                          child: Row(children: [
                            const Icon(Icons.people,
                                size: 18, color: AppStyles.primary),
                            const SizedBox(width: 6),
                            Text('Мойщики',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppStyles.adaptiveTextPrimary(
                                        context))),
                          ]),
                        ),
                        Expanded(
                          child: _washers.isEmpty
                              ? Center(
                                  child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text('Нет мойщиков',
                                      style: TextStyle(
                                          color:
                                              AppStyles.adaptiveTextSecondary(
                                                  context),
                                          fontSize: 13)),
                                ))
                              : ListView.builder(
                                  itemCount: _washers.length,
                                  itemBuilder: (context, index) {
                                    final w = _washers[index];
                                    final selected =
                                        _selectedWasher == w.username;
                                    return InkWell(
                                      onTap: () => setState(() {
                                        _selectedWasher =
                                            selected ? null : w.username;
                                      }),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppStyles.primary
                                                  .withValues(alpha: 0.12)
                                              : Colors.transparent,
                                          border: Border(
                                            bottom: BorderSide(
                                                color: AppStyles.adaptiveBorder(
                                                        context)
                                                    .withValues(alpha: 0.5)),
                                          ),
                                        ),
                                        child: Row(children: [
                                          Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: selected
                                                  ? AppStyles.primary
                                                  : AppStyles.warning
                                                      .withValues(alpha: 0.15),
                                            ),
                                            child: Icon(Icons.person,
                                                size: 16,
                                                color: selected
                                                    ? Colors.white
                                                    : AppStyles.warning),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              w.displayName.isNotEmpty
                                                  ? w.displayName
                                                  : w.username,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: selected
                                                    ? FontWeight.w600
                                                    : FontWeight.normal,
                                                color: selected
                                                    ? AppStyles.primary
                                                    : AppStyles
                                                        .adaptiveTextPrimary(
                                                            context),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ]),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(width: 1, color: AppStyles.adaptiveBorder(context)),
                // Правая панель: записи
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppStyles.primary.withValues(alpha: 0.08),
                          border: Border(
                              bottom: BorderSide(
                                  color: AppStyles.adaptiveBorder(context))),
                        ),
                        child: Row(children: [
                          const Icon(Icons.list_alt,
                              size: 18, color: AppStyles.primary),
                          const SizedBox(width: 6),
                          Text('Записи (${dayAppts.length})',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      AppStyles.adaptiveTextPrimary(context))),
                        ]),
                      ),
                      Expanded(
                        child: dayAppts.isEmpty
                            ? Center(
                                child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.event_busy,
                                      size: 48,
                                      color:
                                          AppStyles.adaptiveTextMuted(context)),
                                  const SizedBox(height: 8),
                                  Text('Нет записей',
                                      style: TextStyle(
                                          color:
                                              AppStyles.adaptiveTextSecondary(
                                                  context),
                                          fontSize: 14)),
                                ],
                              ))
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: dayAppts.length,
                                itemBuilder: (context, index) {
                                  final a = dayAppts[index];
                                  return _AppointmentCard(
                                    appointment: a,
                                    services: catalogProvider.services,
                                    selectedWasher: _selectedWasher,
                                    washerDisplayName: _washerDisplayName,
                                    onAssign: () => _assignWasher(a),
                                    onRemoveWasher: (username) =>
                                        _removeWasher(a, username),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _assignWasher(Appointment appt) async {
    if (_selectedWasher == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сначала выберите мойщика слева'),
          backgroundColor: AppStyles.warning,
        ),
      );
      return;
    }

    if (appt.assignedWashers.contains(_selectedWasher)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Этот мойщик уже назначен'),
          backgroundColor: AppStyles.warning,
        ),
      );
      return;
    }

    if (appt.assignedWashers.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Максимум 3 мойщика на одну запись'),
          backgroundColor: AppStyles.danger,
        ),
      );
      return;
    }

    final washerName = _washerDisplayName(_selectedWasher!);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppStyles.adaptiveCard(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Назначить мойщика?'),
        content: Text('Добавить "$washerName" на запись '
            '${appt.clientName} (${DateFormat('HH:mm').format(appt.dateTime)})?\n\n'
            'Назначено: ${appt.assignedWashers.length}/3'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Назначить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<AppointmentProvider>();
      final ok = await provider.assignWasher(appt.id, _selectedWasher!);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Мойщик "$washerName" добавлен'),
            backgroundColor: AppStyles.success,
          ),
        );
      }
    }
  }

  Future<void> _removeWasher(Appointment appt, String username) async {
    final washerName = _washerDisplayName(username);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppStyles.adaptiveCard(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Убрать мойщика?'),
        content: Text('Убрать "$washerName" с записи '
            '${appt.clientName} (${DateFormat('HH:mm').format(appt.dateTime)})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Убрать'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = context.read<AppointmentProvider>();
      // assignWasher toggles — if already in list, removes
      final ok = await provider.assignWasher(appt.id, username);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Мойщик "$washerName" убран'),
            backgroundColor: AppStyles.warning,
          ),
        );
      }
    }
  }
}

// ─── Карточка записи ─────────────────────────────────────────────────────────
class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final List<dynamic> services;
  final String? selectedWasher;
  final String Function(String) washerDisplayName;
  final VoidCallback onAssign;
  final void Function(String username) onRemoveWasher;

  const _AppointmentCard({
    required this.appointment,
    required this.services,
    required this.selectedWasher,
    required this.washerDisplayName,
    required this.onAssign,
    required this.onRemoveWasher,
  });

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final time = DateFormat('HH:mm').format(a.dateTime);
    final statusColor = AppStyles.statusColor(a.status);
    final hasWashers = a.assignedWashers.isNotEmpty;
    final canAddMore = a.assignedWashers.length < 3;
    final washerNotYetAssigned =
        selectedWasher != null && !a.assignedWashers.contains(selectedWasher);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppStyles.adaptiveBorder(context)),
      ),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Время + статус
            Row(children: [
              const Icon(Icons.access_time, size: 16, color: AppStyles.primary),
              const SizedBox(width: 4),
              Text(time,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.adaptiveTextPrimary(context))),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(AppStyles.statusLabel(a.status),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor)),
              ),
            ]),
            const SizedBox(height: 8),
            // Клиент
            Row(children: [
              Icon(Icons.person,
                  size: 15, color: AppStyles.adaptiveTextSecondary(context)),
              const SizedBox(width: 4),
              Expanded(
                  child: Text(a.clientName,
                      style: TextStyle(
                          fontSize: 13,
                          color: AppStyles.adaptiveTextPrimary(context)),
                      overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            // Авто
            Row(children: [
              Icon(Icons.directions_car,
                  size: 15, color: AppStyles.adaptiveTextSecondary(context)),
              const SizedBox(width: 4),
              Expanded(
                  child: Text('${a.carModel}  ${a.carNumber}',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.adaptiveTextSecondary(context)),
                      overflow: TextOverflow.ellipsis)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppStyles.primaryBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Бокс №${a.box_index + 1}',
                    style: const TextStyle(
                        color: AppStyles.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 6),
            // Тип мойки + цена
            Row(children: [
              Icon(Icons.local_car_wash,
                  size: 15, color: AppStyles.adaptiveTextSecondary(context)),
              const SizedBox(width: 4),
              Text(context.watch<CatalogProvider>().washTypeName(a.washTypeId),
                  style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.adaptiveTextSecondary(context))),
              const Spacer(),
              Text(
                  '${a.calculateTotalPrice(services.cast(), context.watch<CatalogProvider>().washTypeById(a.washTypeId))} \u20BD',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppStyles.primary)),
            ]),
            const SizedBox(height: 8),

            if (a.additionalServices.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: a.additionalServices.map((id) {
                  final service = context
                      .watch<CatalogProvider>()
                      .services
                      .firstWhere((s) => s.id == id,
                          orElse: () => Service(
                              id: id,
                              name: id,
                              description: '',
                              price: 0,
                              durationMinutes: 0,
                              category: ''));
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppStyles.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(service.name,
                        style: const TextStyle(
                            fontSize: 10, color: AppStyles.primaryDark)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],

            // Назначенные мойщики
            if (hasWashers) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppStyles.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppStyles.success.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.people,
                          size: 14, color: AppStyles.success),
                      const SizedBox(width: 4),
                      Text('Мойщики (${a.assignedWashers.length}/3)',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppStyles.success)),
                    ]),
                    const SizedBox(height: 8),
                    ...a.assignedWashers.map((username) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(children: [
                            const Icon(Icons.check_circle,
                                size: 14, color: AppStyles.success),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(washerDisplayName(username),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: AppStyles.adaptiveTextPrimary(
                                            context)))),
                            GestureDetector(
                              onTap: () => onRemoveWasher(username),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color:
                                      AppStyles.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(Icons.close,
                                    size: 14, color: AppStyles.danger),
                              ),
                            ),
                          ]),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 6),
            ],

            // Кнопка добавить мойщика
            if (canAddMore)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add, size: 16),
                  label: Text(
                    selectedWasher != null && washerNotYetAssigned
                        ? 'Добавить мойщика'
                        : hasWashers
                            ? 'Выберите мойщика для добавления'
                            : 'Выберите мойщика',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        selectedWasher != null && washerNotYetAssigned
                            ? AppStyles.primary
                            : AppStyles.adaptiveTextSecondary(context),
                    side: BorderSide(
                      color: selectedWasher != null && washerNotYetAssigned
                          ? AppStyles.primary
                          : AppStyles.adaptiveBorder(context),
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                  ),
                  onPressed: selectedWasher != null && washerNotYetAssigned
                      ? onAssign
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
