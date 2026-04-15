import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_styles.dart';
import '../models/appointment.dart';
import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import '../data/initial_data.dart';
import '../models/service.dart';

// ─── Форматтер гос. номера (синхронизирован с клиентом) ──────────────────────
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

  final _nameFocus = FocusNode();
  final _modelFocus = FocusNode();
  final _numberFocus = FocusNode();

  late WashType _washType;
  late Set<String> _selectedAddServices;
  late DateTime _dateTime;
  late String _status;
  String? _selectedPromoName; // Выбранная акция

  bool get _isEditing => widget.appointment != null;

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _nameCtrl   = TextEditingController(text: a?.clientName ?? '');
    _modelCtrl  = TextEditingController(text: a?.carModel   ?? '');
    _numberCtrl = TextEditingController(text: a?.carNumber  ?? '');
    _notesCtrl  = TextEditingController(text: a?.notes      ?? '');
    _washType            = a?.washType ?? WashType.basic;
    _selectedAddServices = Set.from(a?.additionalServices ?? []);
    _dateTime            = a?.dateTime ?? DateTime.now().add(
        const Duration(days: 1, hours: 10));
    _status              = a?.status   ?? 'scheduled';

    // Извлечение акции из notes
    final notes = a?.notes ?? '';
    if (notes.startsWith('Акция: ')) {
      final fullName = notes.substring('Акция: '.length).split('\n')[0].trim();
      if (fullName.contains('Акция недели')) _selectedPromoName = 'Акция недели';
      else if (fullName.contains('Весенняя акция')) _selectedPromoName = 'Весенняя акция';
      else if (fullName.contains('Выходной пакет')) _selectedPromoName = 'Выходной пакет';
      else if (fullName.contains('Пакет для внедорожников')) _selectedPromoName = 'Пакет для внедорожников';
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
    final promoCfg = _selectedPromoName != null ? getPromoConfig(_selectedPromoName!) : null;
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
            // ── Клиент и авто ──────────────────────────────────────────
            _sectionLabel('Клиент и автомобиль'),
            TextFormField(
              controller: _nameCtrl,
              focusNode: _nameFocus,
              decoration: AppStyles.inputDecoration('Имя клиента',
                  icon: Icons.person),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Введите имя' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _modelCtrl,
              focusNode: _modelFocus,
              decoration: AppStyles.inputDecoration('Марка и модель авто',
                  icon: Icons.directions_car),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Введите модель' : null,
            ),
            const SizedBox(height: 12),
            // Гос номер с форматтером и постоянной подсказкой
            TextFormField(
              controller: _numberCtrl,
              focusNode: _numberFocus,
              style: const TextStyle(
                  color: AppStyles.textPrimary,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600),
              decoration: _plateDecoration(),
              inputFormatters: [_PlateInputFormatter()],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Введите номер';
                final regex = RegExp(r'^[АВЕКМНОРСТУХ]{1}[0-9]{3}[АВЕКМНОРСТУХ]{2}[0-9]{2,3}$');
                if (!regex.hasMatch(v.toUpperCase())) return 'Неверный формат номера';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // ── Дата и время ───────────────────────────────────────────
            _sectionLabel('Дата и время визита'),
            _DateTimeRow(
              dateTime: _dateTime,
              onChanged: (dt) => setState(() => _dateTime = dt),
            ),
            const SizedBox(height: 20),

            // ── Тип мойки ─────────────────────────────────────────────
            _sectionLabel('Тип мойки'),
            Container(
              decoration: AppStyles.cardDecoration,
              child: Column(
                children: WashType.values.map((wt) => RadioListTile<WashType>(
                  value: wt,
                  groupValue: _washType,
                  onChanged: _selectedPromoName != null ? null : (v) => setState(() => _washType = v!),
                  title: Text(wt.displayName, style: AppStyles.bodyLarge),
                  subtitle: Text('от ${wt.basePrice} ₽',
                      style: AppStyles.bodyMedium),
                  activeColor: AppStyles.primary,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                )).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Дополнительные услуги ───
            _sectionLabel('Дополнительные услуги'),
            Container(
              decoration: AppStyles.cardDecoration,
              child: Column(
                children: additionalServiceOptions.map((s) {
                  final price = extraServicePrices[s];
                  final isIncluded = _washType.includedExtras.contains(s) || (promoCfg?.extras.contains(s) ?? false);
                  final isSelected = _selectedAddServices.contains(s) || isIncluded;
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: isIncluded ? null : (v) => setState(() {
                      v! ? _selectedAddServices.add(s) : _selectedAddServices.remove(s);
                    }),
                    title: Text(s, style: AppStyles.bodyLarge.copyWith(
                        color: isIncluded ? AppStyles.textSecondary : null)),
                    subtitle: isIncluded 
                      ? const Text('Включено в тариф/акцию', style: TextStyle(fontSize: 12, color: AppStyles.primary))
                      : (price != null ? Text('+$price ₽', style: AppStyles.bodyMedium) : null),
                    activeColor: isIncluded ? AppStyles.textSecondary : AppStyles.primary,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    dense: true,
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Выбор акции (только для админа) ──
            if (context.read<AuthProvider>().isAdmin) ...[
              _sectionLabel('Применить акцию'),
              DropdownButtonFormField<String?>(
                value: _selectedPromoName,
                decoration: AppStyles.inputDecoration('Выберите акцию', icon: Icons.discount),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Без акции')),
                  const DropdownMenuItem(value: 'Акция недели', child: Text('Акция недели')),
                  const DropdownMenuItem(value: 'Весенняя акция', child: Text('Весенняя акция')),
                  const DropdownMenuItem(value: 'Выходной пакет', child: Text('Выходной пакет')),
                  const DropdownMenuItem(value: 'Пакет для внедорожников', child: Text('Пакет для внедорожников')),
                ],
                onChanged: (v) {
                  setState(() {
                    _selectedPromoName = v;
                    if (v != null) {
                      final cfg = getPromoConfig(v);
                      if (cfg != null) {
                        if (cfg.washTypeName != null) {
                          _washType = WashType.values.firstWhere((e) => e.name == cfg.washTypeName!);
                        }
                        _selectedAddServices.clear();
                        _selectedAddServices.addAll(cfg.extras);
                      }
                    } else {
                      _selectedPromoName = null;
                      // Можно оставить текущие услуги, если нужно
                    }
                  });
                },
              ),
              const SizedBox(height: 20),
            ],

            // ── Статус ────────────────────────────────────────────────
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

            // ── Заметки ───────────────────────────────────────────────
            _sectionLabel('Заметки (необязательно)'),
            TextFormField(
              controller: _notesCtrl,
              decoration: AppStyles.inputDecoration(
                  'Примечания для мойщика', icon: Icons.notes),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            // ── Итоговая цена ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppStyles.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppStyles.primary),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Итого к оплате:', style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold, color: AppStyles.primary)),
                  Text('${_calcPrice()} ₽', style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: AppStyles.primary)),
                ],
              ),
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


  /// Вычислить актуальную цену по текущим услугам.
  /// Для акционных записей: база = promoPrice, прomo-locked extras не прибавляются.
  int _calcPrice() {
    const extraPrices = {
      'Чернение шин': 300, 'Ароматизация': 300, 'Пылесосная уборка': 500,
      'Полировка стёкол': 500, 'Антидождь': 600, 'Обработка арок': 600,
      'Удаление битума': 700, 'Озонирование': 1000, 'Нанесение воска': 1200,
      'Мойка двигателя': 1500, 'Нанесение силанта': 2000, 'Нанесение тефлона': 3000,
      'Химчистка салона': 3500, 'Химчистка кожи': 5000,
      'Детейлинг кузова': 8000, 'Керамическое покрытие': 15000,
    };

    PromoConfig? promoCfg;
    if (_selectedPromoName != null) {
      promoCfg = getPromoConfig(_selectedPromoName!);
    }

    // Базовая цена с учетом процента скидки или фиксированной цены акции
    int p = _washType.basePrice;
    
    if (_selectedPromoName == 'Акция недели') {
      p = 1600;
    } else if (_selectedPromoName == 'Весенняя акция') {
      p = 2000;
    } else if (_selectedPromoName == 'Пакет для внедорожников') {
      p = 2000;
    } else if (promoCfg != null && promoCfg.discountPercent > 0) {
      p = (p * (100 - promoCfg.discountPercent) / 100).round();
    }

    // Услуги, которые не оплачиваются отдельно
    final locked = <String>{
      ..._washType.includedExtras,
      ...?promoCfg?.extras,
    };

    // Считаем только то, что НЕ входит в базу или акцию
    for (final e in _selectedAddServices) {
      if (!locked.contains(e)) {
        p += extraPrices[e] ?? 0;
      }
    }
    return p;
  }

  void _save() {
    // 1. Явная проверка значений перед валидацией формы
    if (_nameCtrl.text.trim().isEmpty) {
      _nameFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите имя клиента'), backgroundColor: AppStyles.danger));
      return;
    }
    if (_modelCtrl.text.trim().isEmpty) {
      _modelFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите модель авто'), backgroundColor: AppStyles.danger));
      return;
    }
    if (_numberCtrl.text.trim().isEmpty) {
      _numberFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Введите гос. номер'), backgroundColor: AppStyles.danger));
      return;
    }

    if (!_formKey.currentState!.validate()) return;
    
    // 2. Валидация акции
    if (_selectedPromoName != null) {
      final cfg = getPromoConfig(_selectedPromoName!);
      if (cfg != null) {
        final error = _validatePromo(cfg);
        if (error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(error),
            backgroundColor: AppStyles.danger,
          ));
          return;
        }
      }
    }

    final provider = context.read<AppProvider>();
    final newPrice = _calcPrice();
    
    // Формируем примечание: сохраняем акцию, если выбрана
    String finalNotes = _notesCtrl.text.trim();
    
    // Удаляем старую строку акции, если она есть
    final lines = finalNotes.split('\n');
    final cleanLines = lines.where((line) => !line.trim().startsWith('Акция: '));
    finalNotes = cleanLines.join('\n').trim();

    if (_selectedPromoName != null) {
      finalNotes = 'Акция: $_selectedPromoName\n$finalNotes'.trim();
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
        washType: _washType,
        additionalServices: _selectedAddServices.toList(),
        status: _status,
        notes: finalNotes,
        paidPrice: newPrice,
        originalPrice: origPrice,
        isModifiedByAdmin: true,
      ));
    } else {
      provider.addAppointment(Appointment(
        id: 'a_${DateTime.now().millisecondsSinceEpoch}',
        clientName: _nameCtrl.text.trim(),
        carModel: _modelCtrl.text.trim(),
        carNumber: _numberCtrl.text.trim().toUpperCase(),
        dateTime: _dateTime,
        washType: _washType,
        additionalServices: _selectedAddServices.toList(),
        status: _status,
        notes: finalNotes,
        ownerUsername: '',
        promoPrice: 0,
        paidPrice: newPrice,
        originalPrice: newPrice,
        isModifiedByAdmin: true,
      ));
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isEditing ? 'Запись обновлена' : 'Запись создана'),
      backgroundColor: AppStyles.success,
    ));
  }

  // Валидация условий акции
  String? _validatePromo(PromoConfig cfg) {
    if (cfg.washTypeName != null && _washType.name != cfg.washTypeName) {
      return 'Акция "$_selectedPromoName" требует тип мойки: ${_getWashTypeDisplayName(cfg.washTypeName!)}';
    }
    if (cfg.weekendOnly) {
      final weekday = _dateTime.weekday;
      if (weekday != DateTime.saturday && weekday != DateTime.sunday) {
        return 'Акция "$_selectedPromoName" действует только в выходные дни';
      }
    }
    return null;
  }
  
  String _getWashTypeDisplayName(String name) {
    final t = WashType.values.firstWhere((e) => e.name == name, orElse: () => WashType.basic);
    return t.displayName;
  }
}

// ─── Выбор даты и времени ─────────────────────────────────────────────────────
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