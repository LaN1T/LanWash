import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../models/service.dart';

class ClientAppointmentDetailScreen extends StatelessWidget {
  final Appointment appointment;
  const ClientAppointmentDetailScreen({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final catalogProvider = context.watch<CatalogProvider>();
    final auth = context.read<AuthProvider>();
    final services = catalogProvider.services;
    final a = appointmentProvider.appointments.firstWhere(
      (x) => x.id == appointment.id,
      orElse: () => appointment,
    );
    final washType = catalogProvider.washTypeById(a.washTypeId);

    // Расчет длительности
    final duration =
        a.calculateTotalPrice(services.cast<Service>(), washType) >= 0
            ? (washType?.durationMinutes ?? 30) +
                a.additionalServices
                    .where((id) =>
                        !(washType?.includedExtraIds.contains(id) ?? false))
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
    final endTime = a.dateTime.add(Duration(minutes: duration.toInt()));
    final timeStr =
        '${DateFormat('HH:mm', 'ru').format(a.dateTime)} — ${DateFormat('HH:mm', 'ru').format(endTime)}';

    final color = AppStyles.statusColor(a.status);

    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Детали записи', style: TextStyle(fontSize: 18)),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: AppStyles.adaptiveTextPrimary(context),
      ),
      body: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.66),
        child: SingleChildScrollView(
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Icon(AppStyles.statusIcon(a.status),
                        color: color, size: 32),
                    const SizedBox(width: 16),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Статус', style: AppStyles.bodySmall),
                          Text(AppStyles.statusLabel(a.status),
                              style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: color)),
                        ]),
                  ]),
                ),
              ]),
            ),
            _InfoTile(Icons.calendar_today_rounded, 'Дата',
                DateFormat('d MMMM yyyy', 'ru').format(a.dateTime)),
            _InfoTile(Icons.access_time_rounded, 'Время', timeStr),
            _InfoTile(Icons.directions_car_rounded, 'Автомобиль',
                '${a.carModel} · ${a.carNumber}'),
            _InfoTile(Icons.local_car_wash_rounded, 'Услуга',
                catalogProvider.washTypeName(a.washTypeId)),
            _InfoTile(Icons.layers_rounded, 'Бокс', 'Бокс №${a.box_index + 1}'),
            _InfoTile(Icons.payments_rounded, 'Итого',
                '${a.calculateTotalPrice(services, washType)} ₽'),
            if (a.additionalServices.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Дополнительные услуги',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.3),
                decoration: AppStyles.cardDecoration,
                child: ListView(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  children: a.additionalServices.map((id) {
                    final svc = services.firstWhere((s) => s.id == id,
                        orElse: () => Service(
                            id: id,
                            name: id,
                            description: '',
                            price: 0,
                            durationMinutes: 0,
                            category: '',
                            isFavorite: false,
                            isFromApi: false));
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        const Icon(Icons.add_circle_outline,
                            size: 18, color: AppStyles.primary),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(svc.name,
                                style: const TextStyle(fontSize: 14))),
                        const SizedBox(width: 8),
                        Text('${svc.price} ₽',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ]),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (a.status == 'scheduled') ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Опаздываю на',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [15, 30, 60].map((minutes) {
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(right: minutes == 60 ? 0 : 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.timer, size: 18),
                          label: Text('$minutes мин'),
                          onPressed: () => _confirmLate(
                              context, appointmentProvider, auth, a.id, minutes),
                          backgroundColor:
                              AppStyles.warning.withValues(alpha: 0.15),
                          side: BorderSide(
                              color: AppStyles.warning.withValues(alpha: 0.4)),
                          labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showQrCode(context, a.id),
                    icon: const Icon(Icons.qr_code, size: 18, color: AppStyles.primary),
                    label: const Text('Показать QR-код',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppStyles.primary)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppStyles.primary,
                      side: const BorderSide(color: AppStyles.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (a.status == 'scheduled' || a.status == 'in_progress') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showCancelBottomSheet(
                        context, appointmentProvider, auth, a.id),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Отменить запись',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppStyles.danger,
                      side: const BorderSide(color: AppStyles.danger),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  void _showQrCode(BuildContext context, String appointmentId) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppStyles.adaptiveCard(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'QR-код записи',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.adaptiveTextPrimary(context),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: appointmentId,
                  size: 220,
                  backgroundColor: Colors.white,
                  semanticsLabel: 'QR-код записи на мойку',
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Покажите этот код мойщику для начала мойки',
                style: TextStyle(
                  fontSize: 14,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Закрыть'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmLate(BuildContext context, AppointmentProvider provider,
      AuthProvider auth, String id, int minutes) {
    showDialog(
      context: context,
      builder: (ctx) {
        var isLoading = false;
        String? errorText;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: const Text('Сообщить об опоздании?'),
            content: isLoading
                ? const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Text(errorText ?? 'Вы уверены, что опаздываете на $minutes минут?'),
            actions: isLoading
                ? []
                : [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Назад')),
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          isLoading = true;
                          errorText = null;
                        });
                        final ok = await provider.reportLate(id, minutes, auth);
                        if (!ctx.mounted) return;
                        if (ok) {
                          Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Администратор уведомлён об опоздании на $minutes мин'),
                                  backgroundColor: AppStyles.success),
                            );
                          }
                        } else {
                          setState(() {
                            isLoading = false;
                            errorText = 'Не удалось сообщить об опоздании';
                          });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppStyles.warning,
                          foregroundColor: Colors.white),
                      child: const Text('Подтвердить'),
                    ),
                  ],
          ),
        );
      },
    );
  }

  void _showCancelBottomSheet(BuildContext context,
      AppointmentProvider provider, AuthProvider auth, String id) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        var isLoading = false;
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: bottom),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Отмена записи',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      const Text('Укажите причину отмены (до 500 символов):',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 12),
                      TextField(
                        controller: controller,
                        maxLines: 3,
                        maxLength: 500,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          hintText: 'Причина отмены',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.cancel_outlined),
                          label: Text(isLoading ? 'Отмена...' : 'Подтвердить отмену'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyles.danger,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  final reason = controller.text.trim();
                                  if (reason.isEmpty) {
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content: Text('Укажите причину отмены')),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    isLoading = true;
                                  });
                                  final ok = await provider.cancelWithReason(
                                      id, reason, auth);
                                  if (!ctx.mounted) return;
                                  if (ok) {
                                    Navigator.pop(ctx);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text('Запись отменена'),
                                            backgroundColor: AppStyles.success),
                                      );
                                    }
                                  } else {
                                    setState(() {
                                      isLoading = false;
                                    });
                                    ScaffoldMessenger.of(ctx).showSnackBar(
                                      const SnackBar(
                                          content:
                                              Text('Не удалось отменить запись'),
                                          backgroundColor: AppStyles.danger),
                                    );
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 22, color: AppStyles.primary),
          const SizedBox(width: 16),
          Text(label,
              style: TextStyle(
                  color: AppStyles.adaptiveTextSecondary(context),
                  fontSize: 15)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
      );
}
