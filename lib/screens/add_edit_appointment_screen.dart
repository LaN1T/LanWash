import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_styles.dart';
import '../models/appointment.dart';
import '../models/service.dart';
import '../providers/app_provider.dart';
import '../data/initial_data.dart';

const _ruPlateLetters = 'АВЕКМНОРСТУХ';

class _PlateInputFormatter extends TextInputFormatter {
  static const _enToRuPlate = {
    'A':'А','B':'В','E':'Е','K':'К','M':'М','H':'Н',
    'O':'О','P':'Р','C':'С','T':'Т','Y':'У','X':'Х',
  };
  static const _ruLayoutToPlate = {
    'ф':'А','и':'В','у':'Е','р':'К','ь':'М','т':'Н',
    'щ':'О','з':'Р','с':'С','е':'Т','г':'У','ч':'Х',
    'Ф':'А','И':'В','У':'Е','Р':'К','Ь':'М','Т':'Н',
    'Щ':'О','З':'Р','С':'С','Е':'Т','Г':'У','Ч':'Х',
  };

  String _toPlateChar(String c) {
    if (_ruPlateLetters.contains(c)) return c;
    return _enToRuPlate[c] ?? _ruLayoutToPlate[c] ?? '';
  }

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.toUpperCase();
    final buf = StringBuffer();
    int pos = 0;
    for (int i = 0; i < raw.length && pos < 9; i++) {
      final c = raw[i];
      if (pos == 0 || pos == 4 || pos == 5) {
        final ruC = _toPlateChar(c);
        if (ruC.isNotEmpty) { buf.write(ruC); pos++; }
      } else if ((pos >= 1 && pos <= 3) || (pos >= 6 && pos <= 8)) {
        if (RegExp(r'[0-9]').hasMatch(c)) { buf.write(c); pos++; }
      }
    }
    final result = buf.toString();
    return newValue.copyWith(
      text: result,
      selection: TextSelection.collapsed(offset: result.length),
    );
  }
}

class AddEditAppointmentScreen extends StatefulWidget {
  final Appointment? appointment;
  const AddEditAppointmentScreen({super.key, this.appointment});
  @override State<AddEditAppointmentScreen> createState() => _State();
}

class _State extends State<AddEditAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _numberCtrl;
  late final TextEditingController _notesCtrl;

  String _washTypeId = '';
  late Set<String> _selectedAddServices;
  late DateTime _dateTime;
  late String _status;
  String? _selectedPromoId;

  bool get _isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _nameCtrl   = TextEditingController(text: a?.clientName ?? '');
    _modelCtrl  = TextEditingController(text: a?.carModel   ?? '');
    _numberCtrl = TextEditingController(text: a?.carNumber  ?? '');
    _notesCtrl  = TextEditingController(text: a?.notes      ?? '');
    _washTypeId            = a?.washTypeId ?? '';
    _selectedAddServices   = Set.from(a?.additionalServices ?? []);
    _dateTime              = a?.dateTime ?? DateTime.now().add(
        const Duration(days: 1, hours: 10));
    _status                = a?.status   ?? 'scheduled';
    _selectedPromoId       = a?.promoId;

    WidgetsBinding.instance.addPostFrameCallback((_) => _initDefaults());
  }

  void _initDefaults() {
    final provider = context.read<AppProvider>();
    if (_washTypeId.isEmpty) {
      _washTypeId = provider.washTypeByCode('basic')?.id
          ?? (provider.washTypes.isNotEmpty ? provider.washTypes.first.id : '');
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _modelCtrl.dispose();
    _numberCtrl.dispose(); _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final washTypes = [...provider.washTypes]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final extraServices = provider.services
        .where((s) => s.category != 'Акции')
        .toList()
      ..sort((a, b) => a.category.compareTo(b.category));

    if (_washTypeId.isEmpty && washTypes.isNotEmpty) {
      _washTypeId = provider.washTypeByCode('basic')?.id ?? washTypes.first.id;
    }

    final promo = _selectedPromoId == null
        ? null
        : provider.promoById(_selectedPromoId!);
    final lockedExtras = <String>{};
    final washType = provider.washTypeById(_washTypeId);
    if (washType != null) lockedExtras.addAll(washType.includedExtraIds);
    if (promo != null) lockedExtras.addAll(promo.includedExtraIds);

    for (final id in lockedExtras) {
      _selectedAddServices.add(id);
    }

    return Scaffold(
      backgroundColor: AppStyles.background,
      appBar: AppBar(
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          _isEditing ? 'Редактировать запись' : 'Новая запись',
          style: const TextStyle(color: Colors.white,
              fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppStyles.pagePadding,
          children: [
            _sectionLabel('Клиент и автомобиль'),
            TextFormField(
              controller: _nameCtrl,
              decoration: AppStyles.inputDecoration('Имя клиента',
                  icon: Icons.person),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Введите имя' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modelCtrl,
              decoration: AppStyles.inputDecoration('Марка и модель авто',
                  icon: Icons.directions_car),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Введите модель' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numberCtrl,
              style: const TextStyle(
                  color: AppStyles.textPrimary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600),
              decoration: _plateDecoration(),
              inputFormatters: [_PlateInputFormatter()],
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Введите номер' : null,
            ),
            const SizedBox(height: 20),

            _sectionLabel('Дата и время визита'),
            _DateTimeRow(
              dateTime: _dateTime,
              onChanged: (dt) => setState(() => _dateTime = dt),
            ),
            const SizedBox(height: 20),

            _sectionLabel('Тип мойки'),
            Container(
              decoration: AppStyles.cardDecoration,
              child: Column(
                children: washTypes.map((wt) => RadioListTile<String>(
                  value: wt.id,
                  groupValue: _washTypeId,
                  onChanged: promo != null
                      ? null
                      : (v) => setState(() {
                            final oldWt = provider.washTypeById(_washTypeId);
                            if (oldWt != null) {
                              _selectedAddServices.removeAll(oldWt.includedExtraIds);
                            }
                            _washTypeId = v!;
                            final newWt = provider.washTypeById(v);
                            if (newWt != null) {
                              _selectedAddServices.addAll(newWt.includedExtraIds);
                            }
                          }),
                  title: Text(wt.name, style: AppStyles.bodyLarge),
                  subtitle: Text('от ${wt.basePrice} ₽',
                      style: AppStyles.bodyMedium),
                  activeColor: AppStyles.primary,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('Акция (необязательно)'),
            Container(
              decoration: AppStyles.cardDecoration,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: DropdownButtonFormField<String?>(
                value: _selectedPromoId,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Без акции')),
                  ...provider.promos.map((p) => DropdownMenuItem<String?>(
                    value: p.id,
                    child: Text(p.name, overflow: TextOverflow.ellipsis),
                  )),
                ],
                onChanged: (v) => setState(() {
                  _selectedPromoId = v;
                  if (v != null) {
                    final p = provider.promoById(v);
                    if (p != null) {
                      _washTypeId = p.washTypeId;
                      final wt = provider.washTypeById(_washTypeId);
                      if (wt != null) {
                        _selectedAddServices.addAll(wt.includedExtraIds);
                      }
                      _selectedAddServices.addAll(p.includedExtraIds);
                    }
                  }
                }),
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('Дополнительные услуги'),
            Container(
              decoration: AppStyles.cardDecoration,
              child: Column(
                children: extraServices.map((s) {
                  final isLocked = lockedExtras.contains(s.id);
                  return CheckboxListTile(
                    value: _selectedAddServices.contains(s.id) || isLocked,
                    onChanged: isLocked
                        ? null
                        : (v) => setState(() {
                              v! ? _selectedAddServices.add(s.id)
                                  : _selectedAddServices.remove(s.id);
                            }),
                    title: Text(s.name, style: AppStyles.bodyLarge),
                    subtitle: Text(isLocked
                            ? 'Включено'
                            : '+${s.price} ₽',
                        style: AppStyles.bodyMedium),
                    secondary: isLocked
                        ? const Icon(Icons.lock_rounded,
                            color: AppStyles.primary, size: 18)
                        : null,
                    activeColor: AppStyles.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    dense: true,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('Статус записи'),
            Container(
              decoration: AppStyles.cardDecoration,
              child: Column(
                children: statusOptions.map((s) => RadioListTile<String>(
                  value: s,
                  groupValue: _status,
                  onChanged: (v) => setState(() => _status = v!),
                  title: Text(AppStyles.statusLabel(s),
                      style: AppStyles.bodyLarge),
                  activeColor: AppStyles.statusColor(s),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),

            _sectionLabel('Заметки (необязательно)'),
            TextFormField(
              controller: _notesCtrl,
              decoration: AppStyles.inputDecoration(
                  'Примечания для мойщика', icon: Icons.notes),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              icon: const Icon(Icons.save),
              label: Text(_isEditing
                  ? 'Сохранить изменения' : 'Создать запись'),
              style: AppStyles.primaryButton,
              onPressed: _save,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(text,
        style: AppStyles.label.copyWith(
            fontSize: 13, color: AppStyles.primary)),
  );

  static InputDecoration _plateDecoration() {
    final base = AppStyles.inputDecoration('Гос. номер',
        hint: 'А000АА777', icon: Icons.pin);
    return base.copyWith(
      floatingLabelBehavior: FloatingLabelBehavior.always,
      helperText: 'Формат: А000АА777 · EN→RU авто',
      helperStyle: const TextStyle(
          color: AppStyles.textSecondary, fontSize: 11),
    );
  }

  int _calcPrice(AppProvider provider) {
    final wt = provider.washTypeById(_washTypeId);
    final promo = _selectedPromoId == null
        ? null
        : provider.promoById(_selectedPromoId!);

    final locked = <String>{
      ...?wt?.includedExtraIds,
      ...?promo?.includedExtraIds,
    };

    int base;
    if (promo != null) {
      if (promo.discountPercent > 0) {
        base = (wt?.basePrice ?? 0) * (100 - promo.discountPercent) ~/ 100;
      } else {
        base = promo.price;
      }
    } else {
      base = wt?.basePrice ?? 0;
    }

    int p = base;
    for (final id in _selectedAddServices) {
      if (locked.contains(id)) continue;
      final svc = provider.services.firstWhere(
        (s) => s.id == id,
        orElse: () => Service(id: id, name: id, description: '',
            price: 0, durationMinutes: 0, category: ''),
      );
      p += svc.price;
    }
    return p;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();

    final newPrice = _calcPrice(provider);
    final promo = _selectedPromoId == null
        ? null
        : provider.promoById(_selectedPromoId!);
    final promoPrice = promo == null ? 0
        : (promo.price > 0 ? promo.price : 0);

    final wt = provider.washTypeById(_washTypeId);
    final finalServices = Set<String>.from(_selectedAddServices)
      ..addAll(wt?.includedExtraIds ?? [])
      ..addAll(promo?.includedExtraIds ?? []);

    String finalNotes = _notesCtrl.text.trim();
    if (promo != null && !finalNotes.toLowerCase().contains('акция')) {
      finalNotes = 'Акция: ${promo.name}\n$finalNotes'.trim();
    }

    if (_isEditing) {
      final origPrice = widget.appointment!.originalPrice > 0
          ? widget.appointment!.originalPrice
          : widget.appointment!.paidPrice > 0
              ? widget.appointment!.paidPrice
              : newPrice;
      provider.updateAppointment(widget.appointment!.copyWith(
        clientName: _nameCtrl.text.trim(),
        carModel: _modelCtrl.text.trim(),
        carNumber: _numberCtrl.text.trim().toUpperCase(),
        dateTime: _dateTime,
        washTypeId: _washTypeId,
        additionalServices: finalServices.toList(),
        status: _status,
        notes: finalNotes,
        paidPrice: newPrice,
        originalPrice: origPrice,
        isModifiedByAdmin: true,
        promoId: _selectedPromoId,
        promoPrice: promoPrice,
      ));
    } else {
      provider.addAppointment(Appointment(
        id: 'a_${DateTime.now().millisecondsSinceEpoch}',
        clientName: _nameCtrl.text.trim(),
        carModel: _modelCtrl.text.trim(),
        carNumber: _numberCtrl.text.trim().toUpperCase(),
        dateTime: _dateTime,
        washTypeId: _washTypeId,
        additionalServices: finalServices.toList(),
        status: _status,
        notes: finalNotes,
        ownerUsername: '',
        promoPrice: promoPrice,
        paidPrice: newPrice,
        originalPrice: newPrice,
        promoId: _selectedPromoId,
      ));
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isEditing ? 'Запись обновлена' : 'Запись создана'),
      backgroundColor: AppStyles.success,
    ));
  }
}

class _DateTimeRow extends StatelessWidget {
  final DateTime dateTime;
  final ValueChanged<DateTime> onChanged;
  const _DateTimeRow({required this.dateTime, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _Picker(
        icon: Icons.calendar_today,
        label: DateFormat('d MMMM yyyy', 'ru').format(dateTime),
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: dateTime,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime.now().add(const Duration(days: 365)),
          );
          if (d != null) onChanged(DateTime(d.year, d.month, d.day,
              dateTime.hour, dateTime.minute));
        },
      )),
      const SizedBox(width: 12),
      Expanded(child: _Picker(
        icon: Icons.access_time,
        label: DateFormat('HH:mm').format(dateTime),
        onTap: () async {
          final t = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(dateTime),
          );
          if (t != null) onChanged(DateTime(dateTime.year, dateTime.month,
              dateTime.day, t.hour, t.minute));
        },
      )),
    ]);
  }
}

class _Picker extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Picker({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppStyles.divider),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: AppStyles.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppStyles.bodyLarge,
            overflow: TextOverflow.ellipsis)),
      ]),
    ),
  );
}
