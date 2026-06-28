import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../models/promo.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalog_provider.dart';
import '../../models/car.dart';
import '../../models/subscription.dart';
import '../../services/api_service.dart';
import 'client_shell.dart';
import '../../core/service_locator.dart';
import 'car_list_screen.dart';
import 'booking/step_indicator.dart';
import 'booking/datetime_step.dart';
import 'booking/service_step.dart';
import 'booking/confirmation_step.dart';
import 'booking/bottom_bar.dart';
import '../../usecases/booking_price_calculator.dart';

// ─── Основной виджет ─────────────────────────────────────────────────────────
class BookingWizardScreen extends StatefulWidget {
  final Promo? initialPromo;
  final Appointment? templateAppointment;
  const BookingWizardScreen(
      {super.key, this.initialPromo, this.templateAppointment});
  @override
  State<BookingWizardScreen> createState() => _BWState();
}

class _BWState extends State<BookingWizardScreen> {
  final _pageCtrl = PageController();
  final _serviceScrollCtrl = ScrollController();
  int _step = 0;

  late DateTime _selectedDate;
  int _selectedSlotIndex = -1; // -1 means no selection

  String _washTypeId = '';
  late Set<String> _extras;
  late TextEditingController _nameCtrl;
  late TextEditingController _brandCtrl;
  late TextEditingController _modelCtrl;
  String? _selectedBrand;
  late TextEditingController _numCtrl;
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  List<Car> _cars = [];
  int? _selectedCarId;

  List<Subscription> _subscriptions = [];
  int? _selectedSubscriptionId;

  Promo? get _promo =>
      widget.templateAppointment != null ? null : widget.initialPromo;
  bool get _isPromo => _promo != null;

  bool get _weekendOnly => _promo?.weekendOnly ?? false;

  BookingPriceCalculator get _calculator {
    final catalog = context.read<CatalogProvider>();
    return BookingPriceCalculator(
      washType: catalog.washTypeById(_washTypeId),
      extras: _extras,
      promo: _promo,
      services: catalog.services,
    );
  }

  Subscription? get _selectedSubscription {
    if (_selectedSubscriptionId == null) return null;
    try {
      return _subscriptions.firstWhere((s) => s.id == _selectedSubscriptionId);
    } catch (_) {
      return null;
    }
  }

  bool get _subscriptionSelected => _selectedSubscription != null;

  int get _finalPrice => _subscriptionSelected ? 0 : _calculator.finalPrice;

  int get _regularPrice => _subscriptionSelected ? _calculator.finalPrice : _calculator.regularPrice;

  bool get _hasDiscount => !_subscriptionSelected && _calculator.hasDiscount;

  DateTime _nextValidDate() {
    DateTime d = DateTime.now();
    if (!_weekendOnly) return d;
    while (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  bool _isDateAllowed(DateTime d) {
    if (!_weekendOnly) return true;
    return d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
  }

  void _updateBusySlots() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    context.read<AppointmentProvider>().fetchBusySlots(dateStr);
  }

  bool _isSlotAvailable(DateTime dt, int duration) {
    // Check if slot is in the past
    if (dt.isBefore(DateTime.now())) return false;

    // Logic from prompt: startTime + durationMinutes + 5 <= 22:00
    final totalMinutes = dt.hour * 60 + dt.minute + duration + 5;
    if (totalMinutes > 22 * 60) return false;

    final busy =
        context.read<AppointmentProvider>().busySlots['busy_slots'] as List?;
    if (busy == null) return true;

    final start = dt;
    final end = dt.add(Duration(minutes: duration));

    // Check if at least one box is free
    for (int boxIdx = 0; boxIdx < busy.length; boxIdx++) {
      bool isBoxFree = true;
      for (final slot in busy[boxIdx]) {
        final slotStart = DateTime.parse(slot['start']);
        final slotEnd = DateTime.parse(slot['end']);

        if (start.isBefore(slotEnd) && end.isAfter(slotStart)) {
          isBoxFree = false;
          break;
        }
      }
      if (isBoxFree) return true;
    }
    return false;
  }

  int _getDuration() => _calculator.duration;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    final existingCar = user?.carModel ?? '';
    final parts =
        existingCar.trim().split(' ').where((s) => s.isNotEmpty).toList();
    _brandCtrl =
        TextEditingController(text: parts.isNotEmpty ? parts.first : '');
    _modelCtrl = TextEditingController(
        text: parts.length > 1 ? parts.sublist(1).join(' ') : '');
    _selectedBrand = _brandCtrl.text.isNotEmpty ? _brandCtrl.text : null;
    _numCtrl = TextEditingController(text: user?.carNumber ?? '');
    _extras = {};
    _selectedDate = _nextValidDate();

    if (widget.templateAppointment != null) {
      final template = widget.templateAppointment!;
      _nameCtrl.text = template.clientName;
      final carParts = template.carModel
          .trim()
          .split(' ')
          .where((s) => s.isNotEmpty)
          .toList();
      _brandCtrl.text = carParts.isNotEmpty ? carParts.first : '';
      _modelCtrl.text =
          carParts.length > 1 ? carParts.sublist(1).join(' ') : '';
      _selectedBrand = _brandCtrl.text.isNotEmpty ? _brandCtrl.text : null;
      _numCtrl.text = template.carNumber;
      final catalogProvider = context.read<CatalogProvider>();
      final wtExists =
          catalogProvider.washTypeById(template.washTypeId) != null;
      _washTypeId = wtExists ? template.washTypeId : '';
      _extras = Set.from(template.additionalServices);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initFromProvider();
      _updateBusySlots();
      _loadCars();
      _loadSubscriptions();
    });
  }

  Future<void> _loadCars() async {
    final cars = await sl<ApiService>().getCars();
    if (mounted) {
      setState(() {
        _cars = cars;
        if (_cars.isNotEmpty) {
          final primary =
              _cars.where((c) => c.isPrimary).firstOrNull ?? _cars.first;
          _selectedCarId = primary.id;
          // Don't overwrite template appointment car data
          if (widget.templateAppointment == null) {
            _applyCarSelection(primary);
          }
        }
      });
    }
  }

  Future<void> _loadSubscriptions() async {
    final subs = await sl<ApiService>().getMySubscriptions();
    if (mounted) {
      setState(() {
        _subscriptions = subs;
        _validateSubscriptionSelection();
      });
    }
  }

  List<Subscription> get _availableSubscriptions {
    if (_washTypeId.isEmpty) return [];
    return _subscriptions.where((s) {
      if (!s.isActive) return false;
      return s.washTypeId == _washTypeId;
    }).toList();
  }

  void _validateSubscriptionSelection() {
    final available = _availableSubscriptions;
    if (_selectedSubscriptionId != null &&
        !available.any((s) => s.id == _selectedSubscriptionId)) {
      _selectedSubscriptionId = null;
    }
  }

  void _applyCarSelection(Car car) {
    _brandCtrl.text = car.brand;
    _modelCtrl.text = car.model;
    _selectedBrand = car.brand.isNotEmpty ? car.brand : null;
    _numCtrl.text = car.number;
  }

  void _initFromProvider() {
    if (widget.templateAppointment != null) return;
    final catalogProvider = context.read<CatalogProvider>();
    if (_isPromo) {
      _washTypeId = _promo!.washTypeId;
      _extras = Set.from(_promo!.includedExtraIds);
    } else {
      final basic = catalogProvider.washTypeByCode('basic') ??
          (catalogProvider.washTypes.isNotEmpty
              ? catalogProvider.washTypes.first
              : null);
      _washTypeId = basic?.id ?? '';
    }
    _addIncludedExtras();
    if (mounted) setState(() {});
  }

  void _addIncludedExtras() {
    final wt = context.read<CatalogProvider>().washTypeById(_washTypeId);
    if (wt != null) _extras.addAll(wt.includedExtraIds);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _serviceScrollCtrl.dispose();
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _numCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && !_formKey.currentState!.validate()) {
      _serviceScrollCtrl.animateTo(0,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
      return;
    }
    if (_step == 1 && _selectedSlotIndex == -1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Пожалуйста, выберите время для записи.'),
        backgroundColor: AppStyles.danger,
      ));
      return;
    }

    if (_step < 2) {
      setState(() => _step++);
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageCtrl.previousPage(
          duration: const Duration(milliseconds: 350), curve: Curves.easeInOut);
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _confirm() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final auth = context.read<AuthProvider>();
    final login = auth.userLogin.toLowerCase();
    final selectedCar = _cars.where((c) => c.id == _selectedCarId).firstOrNull;
    final ok = await context.read<AppointmentProvider>().addAppointment(
        Appointment(
          id: '',
          clientName: _nameCtrl.text.trim(),
          carModel: '${_brandCtrl.text.trim()} ${_modelCtrl.text.trim()}',
          carNumber: _numCtrl.text.trim().toUpperCase(),
          carId: selectedCar?.id,
          dateTime: _finalDateTime,
          washTypeId: _washTypeId,
          additionalServices: _extras.toList(),
          status: 'scheduled',
          notes: _isPromo ? 'Акция: ${_promo!.name}' : '',
          ownerUsername: login,
          promoPrice: _isPromo
              ? (_promo!.price > 0 ? _promo!.price : _calculator.promoBasePrice)
              : 0,
          paidPrice: _finalPrice,
          subscriptionId: _selectedSubscriptionId,
          promoId: _promo?.id,
        ),
        auth);
    setState(() => _isSaving = false);
    if (mounted) {
      if (ok) {
        Navigator.of(context).popUntil((route) => route.isFirst);
        ClientShell.shellKey.currentState?.switchToBookings();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Запись успешно создана!'),
          ]),
          backgroundColor: AppStyles.success,
          duration: Duration(seconds: 3),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Не удалось создать запись. Попробуйте ещё раз.'),
          backgroundColor: AppStyles.danger,
        ));
      }
    }
  }

  DateTime get _finalDateTime {
    if (_selectedSlotIndex == -1) return DateTime.now(); // Should not happen
    final hour = 8 + (_selectedSlotIndex ~/ 2);
    final minute = (_selectedSlotIndex % 2) * 30;
    return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
        hour, minute);
  }

  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.watch<CatalogProvider>();
    final washTypes = [...catalogProvider.washTypes]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (_washTypeId.isEmpty && washTypes.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child:
                Container(height: 1, color: AppStyles.adaptiveBorder(context))),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: _back,
        ),
        title: Row(children: [
          Text('Запись на мойку',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.adaptiveTextPrimary(context))),
          if (_isPromo) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: AppStyles.primaryGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Акция',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      ),
      body: Column(children: [
        StepIndicator(current: _step),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ServiceStep(
                scrollCtrl: _serviceScrollCtrl,
                formKey: _formKey,
                washTypes: washTypes,
                washTypeId: _washTypeId,
                extras: _extras,
                lockedExtras: _calculator.lockedExtras,
                nameCtrl: _nameCtrl,
                brandCtrl: _brandCtrl,
                modelCtrl: _modelCtrl,
                selectedBrand: _selectedBrand,
                onBrandSelected: (brand) =>
                    setState(() => _selectedBrand = brand),
                numCtrl: _numCtrl,
                isPromo: _isPromo,
                cars: _cars,
                selectedCarId: _selectedCarId,
                onCarSelected: (carId) {
                  setState(() {
                    _selectedCarId = carId;
                    final car = _cars.where((c) => c.id == carId).firstOrNull;
                    if (car != null) _applyCarSelection(car);
                  });
                },
                onAddCar: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CarListScreen()),
                  );
                  await _loadCars();
                },
                onWashTypeChanged: (wt) => setState(() {
                  final oldWt = catalogProvider.washTypeById(_washTypeId);
                  if (oldWt != null) _extras.removeAll(oldWt.includedExtraIds);
                  _washTypeId = wt.id;
                  _extras.addAll(wt.includedExtraIds);
                  _validateSubscriptionSelection();
                }),
                onExtrasChanged: (id, v) => setState(() {
                  if (!v && _calculator.lockedExtras.contains(id)) return;
                  v ? _extras.add(id) : _extras.remove(id);
                }),
              ),
              DateTimeStep(
                selectedDate: _selectedDate,
                selectedSlot: _selectedSlotIndex,
                weekendOnly: _weekendOnly,
                isDateAllowed: _isDateAllowed,
                onDateChanged: (d) {
                  setState(() {
                    _selectedDate = d;
                    _selectedSlotIndex = -1; // Reset selection
                  });
                  _updateBusySlots();
                },
                onSlotChanged: (i) => setState(() => _selectedSlotIndex = i),
                isSlotAvailable: _isSlotAvailable,
                getDuration: _getDuration,
                getFinalDateTime: () => _finalDateTime,
              ),
              ConfirmationStep(
                date: DateFormat('d MMMM yyyy, HH:mm', 'ru')
                    .format(_finalDateTime),
                washType: catalogProvider.washTypeById(_washTypeId),
                extras: _extras.toList(),
                services: catalogProvider.services,
                name: _nameCtrl.text,
                car: '${_brandCtrl.text.trim()} ${_modelCtrl.text.trim()}',
                number: _numCtrl.text,
                finalPrice: _finalPrice,
                regularPrice: _regularPrice,
                hasDiscount: _hasDiscount,
                promoName: _isPromo ? _promo!.name : null,
                totalDurationLabel: _calculator.durationLabel,
                subscriptions: _availableSubscriptions,
                selectedSubscriptionId: _selectedSubscriptionId,
                selectedSubscriptionName: _selectedSubscription?.name,
                onSubscriptionChanged: (id) =>
                    setState(() => _selectedSubscriptionId = id),
              ),
            ],
          ),
        ),
        BottomBar(
          step: _step,
          onAction: _step < 2 ? _next : () => _confirm(),
          selectedTimeLabel: _selectedSlotIndex == -1
              ? null
              : DateFormat("d MMMM, HH:mm", "ru").format(_finalDateTime),
        ),
      ]),
    );
  }
}
