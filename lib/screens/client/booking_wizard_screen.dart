import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/appointment.dart';
import '../../models/promo.dart';
import '../../models/service.dart';
import '../../models/wash_type.dart';
import '../../providers/app_provider.dart';
import '../../providers/auth_provider.dart';
import 'client_shell.dart';

// ─── Транслитерация ───────────────────────────────────────────────────────────
const _enToRu = {
  'q':'й','w':'ц','e':'у','r':'к','t':'е','y':'н','u':'г','i':'ш','o':'щ','p':'з',
  '[':'х',']':'ъ','a':'ф','s':'ы','d':'в','f':'а','g':'п','h':'р','j':'о','k':'л',
  'l':'д',';':'ж',"'":'э','z':'я','x':'ч','c':'с','v':'м','b':'и','n':'т','m':'ь',
  ',':'б','.':'ю',
  'Q':'Й','W':'Ц','E':'У','R':'К','T':'Е','Y':'Н','U':'Г','I':'Ш','O':'Щ','P':'З',
  'A':'Ф','S':'Ы','D':'В','F':'А','G':'П','H':'Р','J':'О','K':'Л','L':'Д',
  'Z':'Я','X':'Ч','C':'С','V':'М','B':'И','N':'Т','M':'Ь',
};
const _ruToEn = {
  'й':'q','ц':'w','у':'e','к':'r','е':'t','н':'y','г':'u','ш':'i','щ':'o','з':'p',
  'ф':'a','ы':'s','в':'d','а':'f','п':'g','р':'h','о':'j','л':'k',
  'д':'l','я':'z','ч':'x','с':'c','м':'v','и':'b','т':'n','ь':'m',
  'Й':'Q','Ц':'W','У':'E','К':'R','Е':'T','Н':'Y','Г':'U','Ш':'I','Щ':'O','З':'P',
  'Ф':'A','Ы':'S','В':'D','А':'F','П':'G','Р':'H','О':'J','Л':'K','Д':'L',
  'Я':'Z','Ч':'X','С':'C','М':'V','И':'B','Т':'N','Ь':'M',
};

String _translitToRu(String input) =>
    input.split('').map((c) => _enToRu[c] ?? c).join();

String _translitToEn(String input) =>
    input.split('').map((c) => _ruToEn[c] ?? c).join();

void _applyTranslitRu(TextEditingController ctrl, String v) {
  final converted = _translitToRu(v);
  if (converted != v) {
    ctrl.value = TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
  }
}

void _applyTranslitEn(TextEditingController ctrl, String v) {
  final converted = _translitToEn(v);
  if (converted != v) {
    ctrl.value = TextEditingValue(
      text: converted,
      selection: TextSelection.collapsed(offset: converted.length),
    );
  }
}

const _ruPlateLetters = 'АВЕКМНОРСТУХ';

String? _validatePlate(String? v) {
  if (v == null || !RegExp(r'^[АВЕКМНОРСТУХ]{1}\d{3}[АВЕКМНОРСТУХ]{2}\d{2,3}$').hasMatch(v.toUpperCase())) {
    return 'Неверный формат (напр. А000АА77)';
  }
  return null;
}

class _PlateInputFormatter extends TextInputFormatter {
  static const _map = {
    'A': 'А', 'B': 'В', 'E': 'Е', 'K': 'К', 'M': 'М', 'H': 'Н',
    'O': 'О', 'P': 'Р', 'C': 'С', 'T': 'Т', 'Y': 'У', 'X': 'Х',
  };

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase();
    final buf = StringBuffer();
    int pos = 0;
    for (int i = 0; i < raw.length && pos < 9; i++) {
      String c = raw[i];
      if (_map.containsKey(c)) c = _map[c]!;
      
      if (pos == 0 || pos == 4 || pos == 5) {
        if (RegExp(r'[АВЕКМНОРСТУХ]').hasMatch(c)) { buf.write(c); pos++; }
      } else if ((pos >= 1 && pos <= 3) || (pos >= 6 && pos <= 8)) {
        if (RegExp(r'[0-9]').hasMatch(c)) { buf.write(c); pos++; }
      }
    }
    final result = buf.toString();
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

// ─── Основной виджет ─────────────────────────────────────────────────────────
class BookingWizardScreen extends StatefulWidget {
  final Promo? initialPromo;
  const BookingWizardScreen({super.key, this.initialPromo});
  @override State<BookingWizardScreen> createState() => _BWState();
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
  late TextEditingController _carCtrl;
  late TextEditingController _numCtrl;
  final _formKey = GlobalKey<FormState>();

  Promo? get _promo => widget.initialPromo;
  bool   get _isPromo => _promo != null;

  bool get _weekendOnly => _promo?.weekendOnly ?? false;

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
    context.read<AppProvider>().fetchBusySlots(dateStr);
  }

  bool _isSlotAvailable(DateTime dt, int duration) {
    // Check if slot is in the past
    if (dt.isBefore(DateTime.now())) return false;

    // Logic from prompt: startTime + durationMinutes + 5 <= 22:00
    final totalMinutes = dt.hour * 60 + dt.minute + duration + 5;
    if (totalMinutes > 22 * 60) return false;

    final busy = context.read<AppProvider>().busySlots['busy_slots'] as List?;
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

  int _getDuration() {
    final provider = context.read<AppProvider>();
    final wt = provider.washTypeById(_washTypeId);
    int duration = wt?.durationMinutes ?? 30;
    
    final locked = _lockedExtras();
    for (final id in _extras) {
      if (!locked.contains(id)) {
        final svc = provider.services.firstWhere((s) => s.id == id, orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: ''));
        duration += svc.durationMinutes;
      }
    }
    return duration;
  }

  Set<String> _lockedExtras() {
    final locked = <String>{...?_washType?.includedExtraIds};
    if (_isPromo) locked.addAll(_promo!.includedExtraIds);
    return locked;
  }

  WashType? get _washType =>
      context.read<AppProvider>().washTypeById(_washTypeId);

  int _extraPrice(String id) {
    final svc = context.read<AppProvider>().services.firstWhere(
      (s) => s.id == id,
      orElse: () => Service(id: id, name: id, description: '',
          price: 0, durationMinutes: 0, category: ''),
    );
    return svc.price;
  }

  int _extraDuration(String id) {
    final svc = context.read<AppProvider>().services.firstWhere(
      (s) => s.id == id,
      orElse: () => Service(id: id, name: id, description: '',
          price: 0, durationMinutes: 0, category: ''),
    );
    return svc.durationMinutes;
  }

  int get _regularPrice {
    final wt = _washType;
    int p = wt?.basePrice ?? 0;
    final washIncluded = wt?.includedExtraIds.toSet() ?? <String>{};
    for (final id in _extras) {
      if (!washIncluded.contains(id)) p += _extraPrice(id);
    }
    return p;
  }

  int get _extrasPrice {
    int p = 0;
    final locked = _lockedExtras();
    for (final id in _extras) {
      if (!locked.contains(id)) p += _extraPrice(id);
    }
    return p;
  }

  int get _promoBasePrice {
    if (!_isPromo) return 0;
    if (_promo!.discountPercent > 0) {
      final base = _washType?.basePrice ?? 0;
      return base * (100 - _promo!.discountPercent) ~/ 100;
    }
    return _promo!.price;
  }

  int get _finalPrice => _isPromo ? _promoBasePrice + _extrasPrice : _regularPrice;
  bool get _hasDiscount => _isPromo && _finalPrice < _regularPrice;

  DateTime get _finalDateTime {
    if (_selectedSlotIndex == -1) return DateTime.now(); // Should not happen
    final hour = 8 + (_selectedSlotIndex ~/ 2);
    final minute = (_selectedSlotIndex % 2) * 30;
    return DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, minute);
  }

  String get _totalDurationLabel {
    final wt = _washType;
    int total = wt?.durationMinutes ?? 0;
    final washIncluded = wt?.includedExtraIds.toSet() ?? <String>{};
    for (final id in _extras) {
      if (washIncluded.contains(id)) continue;
      total += _extraDuration(id);
    }

    final d = total ~/ (24 * 60);
    final h = (total % (24 * 60)) ~/ 60;
    final m = total % 60;

    final parts = <String>[];
    if (d > 0) parts.add('$d д');
    if (h > 0) parts.add('$h ч');
    if (m > 0) parts.add('$m мин');
    
    return parts.isEmpty ? '0 мин' : parts.join(' ');
  }

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl = TextEditingController(text: user?.displayName ?? '');
    _carCtrl  = TextEditingController(text: user?.carModel    ?? '');
    _numCtrl  = TextEditingController(text: user?.carNumber   ?? '');
    _extras = {};
    _selectedDate = _nextValidDate();

    WidgetsBinding.instance.addPostFrameCallback((_) {
        _initFromProvider();
        _updateBusySlots();
    });
  }

  void _initFromProvider() {
    final provider = context.read<AppProvider>();
    if (_isPromo) {
      _washTypeId = _promo!.washTypeId;
      _extras = Set.from(_promo!.includedExtraIds);
    } else {
      final basic = provider.washTypeByCode('basic')
          ?? (provider.washTypes.isNotEmpty ? provider.washTypes.first : null);
      _washTypeId = basic?.id ?? '';
    }
    _addIncludedExtras();
    if (mounted) setState(() {});
  }

  void _addIncludedExtras() {
    final wt = context.read<AppProvider>().washTypeById(_washTypeId);
    if (wt != null) _extras.addAll(wt.includedExtraIds);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _serviceScrollCtrl.dispose();
    _nameCtrl.dispose(); _carCtrl.dispose(); _numCtrl.dispose();
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

  void _confirm() {
    final login = context.read<AuthProvider>().userLogin.toLowerCase();
    context.read<AppProvider>().addAppointment(Appointment(
      id: 'a_${DateTime.now().millisecondsSinceEpoch}',
      clientName: _nameCtrl.text.trim(),
      carModel: _carCtrl.text.trim(),
      carNumber: _numCtrl.text.trim().toUpperCase(),
      dateTime: _finalDateTime,
      washTypeId: _washTypeId,
      additionalServices: _extras.toList(),
      status: 'scheduled',
      notes: _isPromo ? 'Акция: ${_promo!.name}' : '',
      ownerUsername: login,
      promoPrice: _isPromo ? (_promo!.price > 0 ? _promo!.price : _promoBasePrice) : 0,
      paidPrice: _finalPrice,
      promoId: _promo?.id,
    ));
    Navigator.of(context).popUntil((route) => route.isFirst);
    ClientShell.shellKey.currentState?.switchToBookings();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Row(children: [
        Icon(Icons.check_circle_rounded, color: Colors.white),
        SizedBox(width: 10),
        Text('Запись успешно создана!'),
      ]),
      backgroundColor: AppStyles.success,
      duration: const Duration(seconds: 3),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final washTypes = [...provider.washTypes]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    if (_washTypeId.isEmpty && washTypes.isNotEmpty) {
      _washTypeId = _isPromo
          ? _promo!.washTypeId
          : (provider.washTypeByCode('basic')?.id ?? washTypes.first.id);
      _addIncludedExtras();
    }

    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppStyles.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: _back,
        ),
        title: Row(children: [
          const Text('Запись на мойку',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                  color: AppStyles.textPrimary)),
          if (_isPromo) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                gradient: AppStyles.primaryGradient,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Акция', style: TextStyle(
                  color: Colors.white, fontSize: 11,
                  fontWeight: FontWeight.w600)),
            ),
          ],
        ]),
      ),
      body: Column(children: [
        _StepIndicator(current: _step),
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _ServiceStep(
                scrollCtrl: _serviceScrollCtrl,
                formKey: _formKey,
                washTypes: washTypes,
                washTypeId: _washTypeId,
                extras: _extras,
                lockedExtras: _lockedExtras(),
                nameCtrl: _nameCtrl,
                carCtrl: _carCtrl,
                numCtrl: _numCtrl,
                isPromo: _isPromo,
                onWashTypeChanged: (wt) => setState(() {
                  final oldWt = provider.washTypeById(_washTypeId);
                  if (oldWt != null) _extras.removeAll(oldWt.includedExtraIds);
                  _washTypeId = wt.id;
                  _extras.addAll(wt.includedExtraIds);
                }),
                onExtrasChanged: (id, v) => setState(() {
                  if (!v && _lockedExtras().contains(id)) return;
                  v ? _extras.add(id) : _extras.remove(id);
                }),
              ),
              _DateTimeStep(
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
              _ConfirmationStep(
                date: DateFormat('d MMMM yyyy, HH:mm', 'ru').format(_finalDateTime),
                washType: _washType,
                extras: _extras.toList(),
                services: provider.services,
                name: _nameCtrl.text,
                car: _carCtrl.text,
                number: _numCtrl.text,
                finalPrice: _finalPrice,
                regularPrice: _regularPrice,
                hasDiscount: _hasDiscount,
                promoName: _isPromo ? _promo!.name : null,
                totalDurationLabel: _totalDurationLabel,
              ),
            ],
          ),
        ),
        _BottomBar(
          step: _step,
          onAction: _step < 2 ? _next : _confirm,
          selectedTimeLabel: _selectedSlotIndex == -1 ? null : DateFormat("d MMMM, HH:mm", "ru").format(_finalDateTime),
        ),
      ]),
    );
  }
}

// ─── Индикатор шагов ─────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});
  static const _steps = ['Услуга', 'Дата и время', 'Подтверждение'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          return Expanded(child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: i ~/ 2 < current ? AppStyles.primary : AppStyles.border,
              borderRadius: BorderRadius.circular(1),
            ),
          ));
        }
        final idx    = i ~/ 2;
        final done   = idx < current;
        final active = idx == current;
        return Column(mainAxisSize: MainAxisSize.min, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 32, height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppStyles.primary :
                     active ? AppStyles.primaryBg : AppStyles.bgMuted,
              border: Border.all(
                color: (done || active) ? AppStyles.primary : AppStyles.border,
                width: active ? 2 : 1,
              ),
            ),
            child: Center(child: done
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Text('${idx + 1}', style: TextStyle(
                    color: active ? AppStyles.primary : AppStyles.textSecondary,
                    fontSize: 13, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(height: 5),
          Text(_steps[idx], style: TextStyle(
            color: (done || active) ? AppStyles.primary : AppStyles.textMuted,
            fontSize: 10, fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          )),
        ]);
      })),
    );
  }
}

// ─── Шаг 1: Дата и время ─────────────────────────────────────────────────────
class _DateTimeStep extends StatelessWidget {
  final DateTime selectedDate;
  final int selectedSlot;
  final bool weekendOnly;
  final bool Function(DateTime) isDateAllowed;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<int> onSlotChanged;
  final bool Function(DateTime, int) isSlotAvailable;
  final int Function() getDuration;
  final DateTime Function() getFinalDateTime;

  const _DateTimeStep({
    required this.selectedDate,
    required this.selectedSlot,
    required this.weekendOnly,
    required this.isDateAllowed,
    required this.onDateChanged,
    required this.onSlotChanged,
    required this.isSlotAvailable,
    required this.getDuration,
    required this.getFinalDateTime,
  });

  @override
  Widget build(BuildContext context) {
    final days = List.generate(14, (i) => DateTime.now().add(Duration(days: i)));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (weekendOnly)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppStyles.warningBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppStyles.warning.withOpacity(0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: AppStyles.warning, size: 16),
              SizedBox(width: 8),
              Text('Акция доступна только по выходным',
                  style: TextStyle(color: AppStyles.warning, fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        const Text('Выберите дату', style: AppStyles.headingMedium),
        const SizedBox(height: 16),
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            itemBuilder: (_, i) {
              final d = days[i];
              final sel = d.day == selectedDate.day && d.month == selectedDate.month;
              final allowed = isDateAllowed(d);
              return GestureDetector(
                onTap: allowed ? () => onDateChanged(d) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 62, margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppStyles.primary :
                           !allowed ? AppStyles.bgMuted : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: sel ? AppStyles.primary : AppStyles.border),
                    boxShadow: sel ? [BoxShadow(
                        color: AppStyles.primary.withOpacity(0.25),
                        blurRadius: 8, offset: const Offset(0, 3))] : [],
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                    Text(DateFormat('EE', 'ru').format(d).toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                            color: sel ? Colors.white70 :
                                   !allowed ? AppStyles.textMuted :
                                   AppStyles.textSecondary)),
                    const SizedBox(height: 4),
                    Text('${d.day}', style: TextStyle(fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: sel ? Colors.white :
                               !allowed ? AppStyles.textMuted :
                               AppStyles.textPrimary)),
                    Text(DateFormat('MMM', 'ru').format(d),
                        style: TextStyle(fontSize: 11,
                            color: sel ? Colors.white70 :
                                   !allowed ? AppStyles.textMuted :
                                   AppStyles.textSecondary)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 28),
        const Text('Выберите время', style: AppStyles.headingMedium),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5, mainAxisSpacing: 8, crossAxisSpacing: 8,
            childAspectRatio: 2.0,
          ),
          itemCount: (22 - 8) * 2, // 08:00 - 21:30
          itemBuilder: (_, index) {
            final hour = 8 + (index ~/ 2);
            final minute = (index % 2) * 30;
            final startMinutes = hour * 60 + minute;
            final duration = getDuration();
            final endMinutes = startMinutes + duration + 5;
            
            final overflow = endMinutes > 22 * 60 ? endMinutes - (22 * 60) : 0;
            final isTooLong = overflow > 480;
            
            final time = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, hour, minute);
            final busy = isSlotAvailable(time, duration);
            final sel = index == selectedSlot;

            return GestureDetector(
              onTap: (!isTooLong && (busy || overflow > 0)) ? () => onSlotChanged(index) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: sel ? AppStyles.primary : ((busy || overflow > 0) && !isTooLong ? Colors.white : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: sel ? AppStyles.primary : (overflow > 0 ? const Color(0xFFE53935) : AppStyles.border),
                    width: (sel || overflow > 0) ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: sel ? Colors.white : (busy || overflow > 0 ? AppStyles.textPrimary : AppStyles.textMuted),
                        fontSize: 11, fontWeight: FontWeight.bold,
                      )),
                    if (overflow > 0 && !isTooLong) ...[
                      const SizedBox(height: 2),
                      Text('⚠ Завтра до ${((8 * 60 + overflow) ~/ 60).toString().padLeft(2, '0')}:${((8 * 60 + overflow) % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Color(0xFFE53935), fontSize: 9, fontWeight: FontWeight.w600)),
                    ]
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ]),
    );
  }
}

// ─── Шаг 2: Услуги ───────────────────────────────────────────────────────────
class _ServiceStep extends StatelessWidget {
  final ScrollController? scrollCtrl;
  final GlobalKey<FormState> formKey;
  final List<WashType> washTypes;
  final String washTypeId;
  final Set<String> extras;
  final Set<String> lockedExtras;
  final TextEditingController nameCtrl, carCtrl, numCtrl;
  final bool isPromo;
  final ValueChanged<WashType> onWashTypeChanged;
  final void Function(String id, bool value) onExtrasChanged;

  const _ServiceStep({this.scrollCtrl, required this.formKey, required this.washTypes,
    required this.washTypeId, required this.extras, required this.lockedExtras,
    required this.nameCtrl, required this.carCtrl, required this.numCtrl,
    required this.isPromo, required this.onWashTypeChanged,
    required this.onExtrasChanged});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final extraServices = provider.services
        .where((s) => s.category != 'Акции')
        .toList()
      ..sort((a, b) => a.price.compareTo(b.price));

    return SingleChildScrollView(
      controller: scrollCtrl,
      padding: const EdgeInsets.all(20),
      child: Form(
        key: formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Ваши данные', style: AppStyles.headingMedium),
          const SizedBox(height: 14),
          TextFormField(
            controller: nameCtrl,
            style: const TextStyle(color: AppStyles.textPrimary),
            decoration: AppStyles.inputDecoration('Ваше имя',
                icon: Icons.person_outline_rounded),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => _applyTranslitRu(nameCtrl, v),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: carCtrl,
            style: const TextStyle(color: AppStyles.textPrimary),
            decoration: AppStyles.inputDecoration('Марка и модель авто',
                icon: Icons.directions_car_outlined),
            textCapitalization: TextCapitalization.words,
            onChanged: (v) => _applyTranslitEn(carCtrl, v),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите модель' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: numCtrl,
            style: const TextStyle(color: AppStyles.textPrimary,
                letterSpacing: 1.5, fontWeight: FontWeight.w600),
            decoration: _ServiceStep._plateDecoration(),
            inputFormatters: [_PlateInputFormatter()],
            validator: _validatePlate,
          ),
          const SizedBox(height: 24),

          Row(children: [
            const Text('Выберите услугу', style: AppStyles.headingMedium),
            if (isPromo) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppStyles.primaryBg,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('Задано акцией',
                    style: TextStyle(color: AppStyles.primary,
                        fontSize: 11, fontWeight: FontWeight.w500)),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          ...washTypes.map((wt) {
            final sel = washTypeId == wt.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: isPromo ? null : () => onWashTypeChanged(wt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: sel ? AppStyles.primary : AppStyles.border,
                      width: sel ? 2 : 1,
                    ),
                    boxShadow: sel ? [
                      BoxShadow(color: AppStyles.primary.withOpacity(0.1),
                          blurRadius: 10, offset: const Offset(0, 4))
                    ] : [
                      BoxShadow(color: Colors.black.withOpacity(0.02),
                          blurRadius: 4, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(children: [
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(wt.name, style: TextStyle(
                          color: AppStyles.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        )),
                        const SizedBox(height: 4),
                        Text(wt.description, style: const TextStyle(
                          color: AppStyles.textSecondary,
                          fontSize: 12,
                        )),
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.access_time_rounded,
                              size: 14, color: sel ? AppStyles.primary : AppStyles.textSecondary),
                          const SizedBox(width: 4),
                          Text(wt.durationLabel, style: TextStyle(
                              color: sel ? AppStyles.primary : AppStyles.textSecondary,
                              fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(width: 16),
                          Icon(Icons.payments_outlined,
                              size: 14, color: sel ? AppStyles.primary : AppStyles.textSecondary),
                          const SizedBox(width: 4),
                          Text('${wt.basePrice} ₽', style: TextStyle(
                              color: sel ? AppStyles.primary : AppStyles.textSecondary,
                              fontSize: 12, fontWeight: FontWeight.w600)),
                        ]),
                      ],
                    )),
                    if (sel)
                      const Icon(Icons.check_circle_rounded, color: AppStyles.primary, size: 24)
                    else
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppStyles.border, width: 2),
                        ),
                      ),
                  ]),
                ),
              ),
            );
          }),
          
          const SizedBox(height: 12),
          Row(children: [
            const Text('Дополнительно', style: AppStyles.headingMedium),
            if (isPromo) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppStyles.primaryBg,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('Можно добавить',
                    style: TextStyle(color: AppStyles.primary,
                        fontSize: 11, fontWeight: FontWeight.w500)),
              ),
            ],
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: AppStyles.cardDecoration,
            child: Column(
              children: extraServices.asMap().entries.map((entry) {
                final i       = entry.key;
                final svc     = entry.value;
                final checked = extras.contains(svc.id);
                final last    = i == extraServices.length - 1;
                final isFav   = provider.isExtraFavorite(svc.id);
                final wt      = provider.washTypeById(washTypeId);
                final isWashIncluded  = wt?.includedExtraIds.contains(svc.id) ?? false;
                final isPromoIncluded = lockedExtras.contains(svc.id) && !isWashIncluded;
                final locked  = lockedExtras.contains(svc.id);
                return Column(children: [
                  InkWell(
                    onTap: locked ? null : () => onExtrasChanged(svc.id, !checked),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 20, height: 20,
                          decoration: BoxDecoration(
                            color: locked
                                ? AppStyles.primary.withOpacity(0.6)
                                : checked ? AppStyles.primary : Colors.white,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                                color: (locked || checked)
                                    ? AppStyles.primary : AppStyles.border,
                                width: 1.5),
                          ),
                          child: (locked || checked)
                              ? Icon(
                                  locked ? Icons.lock_rounded : Icons.check_rounded,
                                  color: Colors.white, size: 13) : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(child: Text(svc.name, style: TextStyle(
                                    color: checked ? AppStyles.primary : AppStyles.textPrimary,
                                    fontSize: 14,
                                    fontWeight: checked ? FontWeight.w500 : FontWeight.normal,
                                  ))),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: svc.description.isNotEmpty
                                        ? svc.description
                                        : 'Описание услуги пока не добавлено',
                                    triggerMode: TooltipTriggerMode.tap,
                                    child: const Icon(Icons.help_outline,
                                        size: 14, color: AppStyles.textSecondary),
                                  ),
                                ],
                              ),
                              Text(svc.durationLabel,
                                  style: const TextStyle(
                                      color: AppStyles.textSecondary, fontSize: 11)),
                            ],
                          ),
                        ),
                        if (isWashIncluded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppStyles.primaryBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Включено',
                                style: TextStyle(color: AppStyles.primary,
                                    fontSize: 10, fontWeight: FontWeight.w600)),
                          )
                        else if (isPromoIncluded)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppStyles.favorite.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Задано акцией',
                                style: TextStyle(color: AppStyles.favorite,
                                    fontSize: 10, fontWeight: FontWeight.w600)),
                          )
                        else
                          Text('+${svc.price} ₽', style: TextStyle(
                            color: checked ? AppStyles.primary : AppStyles.textSecondary,
                            fontSize: 13, fontWeight: FontWeight.w600,
                          )),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => provider.toggleExtraFavorite(svc.id),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              isFav ? Icons.star_rounded : Icons.star_outline_rounded,
                              size: 20,
                              color: isFav ? AppStyles.favorite : AppStyles.textMuted,
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                  if (!last) Container(
                      height: 1, color: AppStyles.border,
                      margin: const EdgeInsets.only(left: 48)),
                ]);
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  static InputDecoration _plateDecoration() {
    final base = AppStyles.inputDecoration('Гос. номер',
        hint: 'А000АА777', icon: Icons.pin_outlined);
    return base.copyWith(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      helperText: 'Формат: А000АА777 · EN→RU авто',
      helperStyle: const TextStyle(
          color: AppStyles.textSecondary, fontSize: 11),
    );
  }
}

// ─── Шаг 3: Подтверждение ────────────────────────────────────────────────────
class _ConfirmationStep extends StatelessWidget {
  final String date, name, car, number;
  final WashType? washType;
  final List<String> extras;
  final List<Service> services;
  final int finalPrice, regularPrice;
  final bool hasDiscount;
  final String? promoName;
  final String totalDurationLabel;

  const _ConfirmationStep({required this.date, required this.washType, required this.extras,
    required this.services,
    required this.name, required this.car, required this.number,
    required this.finalPrice, required this.regularPrice,
    required this.hasDiscount, this.promoName, required this.totalDurationLabel});

  String _serviceName(String id) {
    for (final s in services) {
      if (s.id == id) return s.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Подтверждение', style: AppStyles.headingMedium),
        const SizedBox(height: 4),
        const Text('Проверьте данные перед записью', style: AppStyles.bodyMedium),
        const SizedBox(height: 20),

        if (promoName != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppStyles.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              const Icon(Icons.local_offer_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(promoName!,
                  style: const TextStyle(color: Colors.white,
                      fontSize: 13, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 14),
        ],

        _ConfirmCard(icon: Icons.event_rounded, label: 'Дата и время',
            value: date, highlight: true),
        const SizedBox(height: 10),

        Container(
          decoration: AppStyles.cardDecoration,
          child: Column(children: [
            _ConfirmRow(Icons.person_outline_rounded, 'Клиент', name),
            Container(height: 1, color: AppStyles.border),
            _ConfirmRow(Icons.directions_car_outlined, 'Автомобиль', car),
            Container(height: 1, color: AppStyles.border),
            _ConfirmRow(Icons.pin_outlined, 'Гос. номер', number),
          ]),
        ),
        const SizedBox(height: 10),

        Container(
          decoration: AppStyles.cardDecoration,
          child: Column(children: [
            _ConfirmRow(Icons.local_car_wash_rounded, 'Тип мойки',
                washType?.name ?? '—'),
            Container(height: 1, color: AppStyles.border),
            _ConfirmRow(Icons.access_time_rounded, 'Время',
                totalDurationLabel),
            if (extras.isNotEmpty) ...[
              Container(height: 1, color: AppStyles.border),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  const Row(children: [
                    Icon(Icons.add_circle_outline_rounded,
                        size: 16, color: AppStyles.textSecondary),
                    SizedBox(width: 10),
                    Text('Доп. услуги', style: TextStyle(
                        color: AppStyles.textSecondary, fontSize: 13)),
                  ]),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6,
                    children: extras.map((id) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppStyles.primaryBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: AppStyles.primary.withOpacity(0.2)),
                      ),
                      child: Text(_serviceName(id), style: const TextStyle(
                          color: AppStyles.primary, fontSize: 12,
                          fontWeight: FontWeight.w500)),
                    )).toList()),
                ]),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppStyles.primaryBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppStyles.primary.withOpacity(0.2)),
          ),
          child: Row(children: [
            const Icon(Icons.payments_outlined, color: AppStyles.primary, size: 22),
            const SizedBox(width: 12),
            const Text('Итого', style: TextStyle(color: AppStyles.textPrimary,
                fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$finalPrice ₽', style: const TextStyle(
                  color: AppStyles.primary, fontSize: 24,
                  fontWeight: FontWeight.bold)),
              if (hasDiscount)
                Text('$regularPrice ₽', style: const TextStyle(
                    color: AppStyles.textSecondary, fontSize: 14,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: AppStyles.textSecondary)),
            ]),
          ]),
        ),
        if (hasDiscount) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppStyles.successBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppStyles.success.withOpacity(0.3)),
            ),
            child: Row(children: [
              const Icon(Icons.savings_rounded, color: AppStyles.success, size: 16),
              const SizedBox(width: 8),
              Text('Экономия по акции: ${regularPrice - finalPrice} ₽',
                  style: const TextStyle(color: AppStyles.success,
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppStyles.bgMuted,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline, color: AppStyles.textSecondary, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'После подтверждения администратор свяжется с вами для уточнения деталей',
              style: TextStyle(color: AppStyles.textSecondary, fontSize: 12),
            )),
          ]),
        ),
        const SizedBox(height: 32),
      ]),
        ),
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool highlight;
  const _ConfirmCard({required this.icon, required this.label,
    required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: AppStyles.cardDecoration,
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppStyles.primaryBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppStyles.primary, size: 20),
      ),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: AppStyles.label),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(
          color: highlight ? AppStyles.primary : AppStyles.textPrimary,
          fontSize: 16, fontWeight: FontWeight.w600,
        )),
      ]),
    ]),
  );
}

class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ConfirmRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: AppStyles.bgMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: AppStyles.textSecondary),
      ),
      const SizedBox(width: 12),
      SizedBox(
        width: 110,
        child: Text(label, style: AppStyles.bodyMedium),
      ),
      Expanded(child: Text(value,
          style: const TextStyle(color: AppStyles.textPrimary,
              fontSize: 14, fontWeight: FontWeight.w600),
          textAlign: TextAlign.right)),
    ]),
  );
}

class _BottomBar extends StatelessWidget {
  final int step;
  final VoidCallback onAction;
  final String? selectedTimeLabel;
  const _BottomBar({required this.step, required this.onAction, this.selectedTimeLabel});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: AppStyles.border)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04),
          blurRadius: 12, offset: const Offset(0, -4))],
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (selectedTimeLabel != null) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppStyles.primaryBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppStyles.primary.withOpacity(0.1)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.event_rounded, color: AppStyles.primary, size: 16),
            const SizedBox(width: 8),
            Text('Выбранное время: $selectedTimeLabel',
                style: const TextStyle(color: AppStyles.primary, fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
      SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: AppStyles.primaryButton,
          onPressed: onAction,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(step == 0 ? 'Далее: выбор времени' :
                 step == 1 ? 'Далее: подтверждение' : 'Записаться',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Icon(step == 2
                ? Icons.check_circle_outline_rounded
                : Icons.arrow_forward_rounded, size: 18),
          ]),
        ),
      ),
    ]),
  );
}
