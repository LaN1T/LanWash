import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../models/service.dart';
import '../../services/api_service.dart';
import 'review_create_screen.dart';

class ClientAppointmentDetailScreen extends StatefulWidget {
  final Appointment appointment;
  const ClientAppointmentDetailScreen({super.key, required this.appointment});

  @override
  State<ClientAppointmentDetailScreen> createState() =>
      _ClientAppointmentDetailScreenState();
}

class _ClientAppointmentDetailScreenState
    extends State<ClientAppointmentDetailScreen> {
  late Future<bool> _hasReviewFuture;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _hasReviewFuture = api.hasReviewForAppointment(widget.appointment.id);
  }

  @override
  Widget build(BuildContext context) {
    final appointmentProvider = context.watch<AppointmentProvider>();
    final catalogProvider = context.watch<CatalogProvider>();
    final auth = context.read<AuthProvider>();
    final services = catalogProvider.services;
    final a = appointmentProvider.appointments.firstWhere(
      (x) => x.id == widget.appointment.id,
      orElse: () => widget.appointment,
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
            if (a.status == 'completed') _buildReviewBanner(context, a.id),
            if (a.status == 'completed' && a.assignedWashers.isNotEmpty)
              _buildTipBanner(context, a.id),
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
                child: ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: a.additionalServices.length,
                  itemBuilder: (context, index) {
                    final id = a.additionalServices[index];
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
                  },
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (a.status == 'scheduled') ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Text('Опаздываю на',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
                          onPressed: () => _confirmLate(context,
                              appointmentProvider, auth, a.id, minutes),
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
                    icon: const Icon(Icons.qr_code,
                        size: 18, color: AppStyles.primary),
                    label: const Text('Показать QR-код',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppStyles.primary)),
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

  Widget _buildReviewBanner(BuildContext context, String appointmentId) {
    return FutureBuilder<bool>(
      future: _hasReviewFuture,
      builder: (ctx, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snapshot.data == true) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: AppStyles.primaryGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppStyles.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.star_rounded, color: Colors.white, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Оцените мойку',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ваш отзыв поможет нам стать лучше',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ReviewCreateScreen(appointmentId: appointmentId),
                      ),
                    );
                    if (mounted) {
                      setState(() {
                        _hasReviewFuture = context
                            .read<ApiService>()
                            .hasReviewForAppointment(appointmentId);
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppStyles.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Оставить отзыв'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTipBanner(BuildContext context, String appointmentId) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyles.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyles.success.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.volunteer_activism,
                  color: AppStyles.success, size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Поблагодарить мойщика',
                  style: TextStyle(
                    color: AppStyles.success,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Оставьте чаевые за отличную работу',
            style: TextStyle(
              color: AppStyles.adaptiveTextSecondary(context),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showTipBottomSheet(context, appointmentId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.success,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Оставить чаевые'),
            ),
          ),
        ],
      ),
    );
  }

  void _showTipBottomSheet(BuildContext context, String appointmentId) {
    final api = context.read<ApiService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final bottom = MediaQuery.of(ctx).viewInsets.bottom;
        return TipBottomSheet(
          appointmentId: appointmentId,
          api: api,
          bottomPadding: bottom,
        );
      },
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
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
                : Text(errorText ??
                    'Вы уверены, что опаздываете на $minutes минут?'),
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
                          label: Text(
                              isLoading ? 'Отмена...' : 'Подтвердить отмену'),
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
                                          content:
                                              Text('Укажите причину отмены')),
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
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
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
                                          content: Text(
                                              'Не удалось отменить запись'),
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

class TipBottomSheet extends StatefulWidget {
  final String appointmentId;
  final dynamic api;
  final double bottomPadding;

  const TipBottomSheet({
    super.key,
    required this.appointmentId,
    required this.api,
    required this.bottomPadding,
  });

  @override
  State<TipBottomSheet> createState() => _TipBottomSheetState();
}

class _TipBottomSheetState extends State<TipBottomSheet> {
  int? _selectedAmount;
  final _customController = TextEditingController();
  String _method = 'sbp';
  bool _isLoading = false;
  String? _sbpUrl;
  bool _showSuccess = false;

  final List<int> _presets = [100, 200, 500, 1000];

  int? get _amount {
    if (_selectedAmount != null) return _selectedAmount;
    final custom = int.tryParse(_customController.text.trim());
    return custom;
  }

  bool get _isValid {
    final a = _amount;
    return a != null && a >= 50 && a <= 50000;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSuccess) {
      return _buildSuccessView();
    }
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Оставить чаевые мойщику?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text('Выберите сумму:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((amount) {
                  final selected = _selectedAmount == amount;
                  return Semantics(
                    label: '$amount рублей',
                    child: ChoiceChip(
                      label: Text('$amount ₽'),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _selectedAmount = amount;
                          _customController.clear();
                        });
                      },
                      selectedColor: AppStyles.primary,
                      labelStyle: TextStyle(
                        color: selected
                            ? Colors.white
                            : AppStyles.adaptiveTextPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _customController,
                keyboardType: TextInputType.number,
                enabled: !_isLoading,
                decoration: InputDecoration(
                  labelText: 'Другая сумма',
                  hintText: 'мин. 50 ₽, макс. 50 000 ₽',
                  prefixIcon: const Icon(Icons.edit),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() => _selectedAmount = null),
              ),
              const SizedBox(height: 16),
              const Text('Способ оплаты:', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 8),
              _MethodRadio(
                value: 'sbp',
                groupValue: _method,
                label: 'СБП',
                icon: Icons.account_balance,
                onChanged: (v) => setState(() => _method = v),
              ),
              _MethodRadio(
                value: 'cash',
                groupValue: _method,
                label: 'Наличные',
                icon: Icons.money,
                onChanged: (v) => setState(() => _method = v),
              ),
              _MethodRadio(
                value: 'app',
                groupValue: _method,
                label: 'Через приложение',
                icon: Icons.phone_android,
                onChanged: (v) => setState(() => _method = v),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || !_isValid ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Подтвердить',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomPadding),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: AppStyles.success, size: 56),
              const SizedBox(height: 16),
              const Text('Спасибо!',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_method == 'sbp' && _sbpUrl != null) ...[
                Text(
                  'Для оплаты через СБП нажмите кнопку ниже:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppStyles.adaptiveTextSecondary(context)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _openSbpUrl,
                    icon: const Icon(Icons.open_in_browser),
                    label: const Text('Открыть в банке'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyles.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else ...[
                Text(
                  'Передайте мойщику при встрече.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppStyles.adaptiveTextSecondary(context)),
                ),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    try {
      final result = await widget.api.createTip(
        appointmentId: widget.appointmentId,
        amount: _amount!,
        method: _method,
      );
      result.when(
        success: (tip) {
          if (_method == 'sbp') {
            _sbpUrl = tip.sbpUrl;
          }
          if (mounted) {
            setState(() {
              _isLoading = false;
              _showSuccess = true;
            });
          }
        },
        failure: (err) {
          if (mounted) {
            setState(() => _isLoading = false);
            final msg = err.message.isNotEmpty
                ? err.message
                : 'Не удалось создать чаевые. Возможно, вы уже оставляли чаевые на эту запись.';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(msg), backgroundColor: AppStyles.danger),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Ошибка: $e'), backgroundColor: AppStyles.danger),
        );
      }
    }
  }

  Future<void> _openSbpUrl() async {
    if (_sbpUrl == null) return;
    final uri = Uri.parse(_sbpUrl!);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        _showSbpOpenFailure(_sbpUrl!);
      }
    } catch (_) {
      if (mounted) {
        _showSbpOpenFailure(_sbpUrl!);
      }
    }
  }

  void _showSbpOpenFailure(String url) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Не удалось открыть банковское приложение'),
        action: SnackBarAction(
          label: 'Копировать ссылку',
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ссылка скопирована')),
            );
          },
        ),
      ),
    );
  }
}

class _MethodRadio extends StatelessWidget {
  final String value;
  final String groupValue;
  final String label;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const _MethodRadio({
    required this.value,
    required this.groupValue,
    required this.label,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppStyles.primary.withValues(alpha: 0.1)
              : AppStyles.adaptiveCard(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppStyles.primary
                : AppStyles.adaptiveBorder(context),
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: selected
                    ? AppStyles.primary
                    : AppStyles.adaptiveTextSecondary(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: AppStyles.adaptiveTextPrimary(context),
                ),
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              onChanged: (v) => onChanged(v!),
              activeColor: AppStyles.primary,
            ),
          ],
        ),
      ),
    );
  }
}
