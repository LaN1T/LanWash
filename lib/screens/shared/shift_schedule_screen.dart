import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/shift.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class ShiftScheduleScreen extends StatefulWidget {
  const ShiftScheduleScreen({super.key});

  @override
  State<ShiftScheduleScreen> createState() => _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends State<ShiftScheduleScreen> {
  bool _loading = true;
  List<User> _washers = [];
  List<Shift> _shifts = [];
  late DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  DateTime _mondayOf(DateTime date) {
    final wd = date.weekday;
    return DateTime(date.year, date.month, date.day)
        .subtract(Duration(days: wd - 1));
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final api = context.read<ApiService>();
    final washers = await api.getWashers();
    final end = _weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('yyyy-MM-dd');
    final shifts = await api.getShifts(fmt.format(_weekStart), fmt.format(end));
    if (mounted) {
      setState(() {
        _washers = washers;
        _shifts = shifts;
        _loading = false;
      });
    }
  }

  void _changeWeek(int delta) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * delta)));
    _loadData();
  }

  Shift? _findShift(int userId, DateTime date) {
    final fmt = DateFormat('yyyy-MM-dd');
    final d = fmt.format(date);
    try {
      return _shifts.firstWhere(
        (s) => s.userId == userId && s.date == d,
      );
    } catch (_) {
      return null;
    }
  }

  bool get _isAdmin {
    final auth = context.read<AuthProvider>();
    return auth.isAdmin;
  }

  bool _canEdit(User washer) {
    if (_isAdmin) return true;
    final me = context.read<AuthProvider>().user;
    return me?.username == washer.username;
  }

  Future<void> _openEditor(User washer, DateTime date, Shift? existing) async {
    final canEdit = _canEdit(washer);
    if (!canEdit && existing == null) return;

    TimeOfDay? start;
    TimeOfDay? end;
    if (existing != null) {
      start = _parseTime(existing.startTime);
      end = _parseTime(existing.endTime);
    }

    final api = context.read<ApiService>();
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _ShiftDialog(
        washerName: washer.displayName,
        date: date,
        existing: existing,
        start: start,
        end: end,
        canEdit: canEdit,
      ),
    );
    if (result == null) return;

    final fmt = DateFormat('yyyy-MM-dd');

    if (result.delete && existing != null) {
      final ok = await api.deleteShift(existing.id);
      if (ok && mounted) {
        _showSnack('Смена удалена');
        _loadData();
      }
      return;
    }

    if (result.start != null && result.end != null) {
      final startStr =
          '${result.start!.hour.toString().padLeft(2, '0')}:${result.start!.minute.toString().padLeft(2, '0')}';
      final endStr =
          '${result.end!.hour.toString().padLeft(2, '0')}:${result.end!.minute.toString().padLeft(2, '0')}';
      final shift = await api.createShift(
        washer.id!,
        fmt.format(date),
        startStr,
        endStr,
      );
      if (shift != null && mounted) {
        final msg = _isAdmin
            ? 'Смена сохранена'
            : 'Заявка на смену отправлена администратору';
        _showSnack(msg);
        _loadData();
      }
    }
  }

  TimeOfDay? _parseTime(String t) {
    final p = t.split(':');
    if (p.length != 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppStyles.danger : AppStyles.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('d MMM');
    final weekLabel = '${fmt.format(_weekStart)} – ${fmt.format(weekEnd)}';

    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        title: const Text('Расписание смен'),
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeWeek(-1),
          ),
          Center(
            child: Text(
              weekLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeWeek(1),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _washers.isEmpty
              ? const Center(child: Text('Нет мойщиков для отображения'))
              : _buildTable(),
    );
  }

  Widget _buildTable() {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    const nameWidth = 150.0;
    const hoursWidth = 70.0;
    const minDayWidth = 100.0;
    final minTableWidth = nameWidth + hoursWidth + days.length * minDayWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = max(constraints.maxWidth, minTableWidth);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SizedBox(
              width: targetWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppStyles.border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Table(
                    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                    columnWidths: {
                      0: const FixedColumnWidth(nameWidth),
                      for (var i = 0; i < days.length; i++)
                        i + 1: const FlexColumnWidth(1),
                      days.length + 1: const FixedColumnWidth(hoursWidth),
                    },
                    border: TableBorder(
                      horizontalInside: BorderSide(color: Colors.grey.shade100),
                      verticalInside: BorderSide(color: Colors.grey.shade100),
                    ),
                    children: [
                      // Header
                      TableRow(
                        decoration: const BoxDecoration(
                          color: AppStyles.bgPage,
                        ),
                        children: [
                          _headerCell('Мойщик', align: Alignment.centerLeft),
                          ...days.map((d) => _headerCell(
                                _dayLabel(d),
                                isWeekend: d.weekday >= 6,
                              )),
                          _headerCell('Часов'),
                        ],
                      ),
                      // Rows
                      ..._washers.map((w) {
                        var totalMinutes = 0;
                        final shiftCells = days.map((d) {
                          final shift = _findShift(w.id!, d);
                          if (shift != null && shift.status == 'confirmed') {
                            totalMinutes += shift.durationMinutes;
                          }
                          return _shiftCell(w, d, shift);
                        }).toList();

                        return TableRow(
                          children: [
                            _nameCell(w),
                            ...shiftCells,
                            _hoursCell(totalMinutes),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerCell(String text,
      {bool isWeekend = false, Alignment align = Alignment.center}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      alignment: align,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isWeekend ? AppStyles.danger : AppStyles.textPrimary,
          height: 1.3,
        ),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return '${names[d.weekday - 1]}\n${d.day}';
  }

  Widget _nameCell(User w) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      child: Text(
        w.displayName,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppStyles.textPrimary,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );
  }

  Widget _shiftCell(User washer, DateTime date, Shift? shift) {
    final canEdit = _canEdit(washer);
    final isWeekend = date.weekday >= 6;

    Color bgColor;
    String label;
    Color textColor;

    if (shift == null) {
      bgColor = Colors.transparent;
      label = '';
      textColor = AppStyles.textSecondary;
    } else if (shift.status == 'pending') {
      bgColor = AppStyles.warning;
      label = '${shift.startTime}\n${shift.endTime}';
      textColor = Colors.white;
    } else if (shift.status == 'rejected') {
      bgColor = AppStyles.danger;
      label = 'Отклонена';
      textColor = Colors.white;
    } else {
      bgColor = AppStyles.primary;
      label = '${shift.startTime}\n${shift.endTime}';
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: () => _openEditor(washer, date, shift),
      child: Container(
        height: 64,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: shift == null
                ? (isWeekend
                    ? AppStyles.danger.withValues(alpha: 0.12)
                    : Colors.grey.shade200)
                : Colors.transparent,
          ),
        ),
        alignment: Alignment.center,
        child: label.isEmpty
            ? canEdit
                ? Icon(Icons.add, size: 18, color: Colors.grey.shade300)
                : const SizedBox.shrink()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      height: 1.4,
                    ),
                  ),
                  if (shift?.status == 'pending')
                    const Text(
                      'Ожидает',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _hoursCell(int totalMinutes) {
    final hours = totalMinutes / 60;
    final hasHours = totalMinutes > 0;
    return Container(
      height: 64,
      alignment: Alignment.center,
      child: Text(
        hours.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 13,
          fontWeight: hasHours ? FontWeight.w700 : FontWeight.w600,
          color: hasHours ? AppStyles.primary : AppStyles.textSecondary,
        ),
      ),
    );
  }
}

class _EditResult {
  final TimeOfDay? start;
  final TimeOfDay? end;
  final bool delete;

  _EditResult({this.start, this.end, this.delete = false});
}

class _ShiftDialog extends StatefulWidget {
  final String washerName;
  final DateTime date;
  final Shift? existing;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final bool canEdit;

  const _ShiftDialog({
    required this.washerName,
    required this.date,
    this.existing,
    this.start,
    this.end,
    required this.canEdit,
  });

  @override
  State<_ShiftDialog> createState() => _ShiftDialogState();
}

class _ShiftDialogState extends State<_ShiftDialog> {
  TimeOfDay? _start;
  TimeOfDay? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.start;
    _end = widget.end;
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? initial) async {
    final init = initial ?? const TimeOfDay(hour: 10, minute: 0);
    return showDialog<TimeOfDay>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _DigitalTimePicker(initial: init),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMMM, EEEE', 'ru_RU').format(widget.date);
    final canSave = _start != null && _end != null;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.washerName),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel,
                style: const TextStyle(
                    fontSize: 14, color: AppStyles.textSecondary)),
            const SizedBox(height: 20),
            _timeRow('Начало', _start, (t) => setState(() => _start = t)),
            const Divider(height: 24),
            _timeRow('Конец', _end, (t) => setState(() => _end = t)),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null && widget.canEdit)
          TextButton(
            onPressed: () => Navigator.pop(context, _EditResult(delete: true)),
            style: TextButton.styleFrom(foregroundColor: AppStyles.danger),
            child: const Text('Удалить'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        if (widget.canEdit)
          ElevatedButton(
            onPressed: canSave
                ? () => Navigator.pop(
                      context,
                      _EditResult(start: _start, end: _end),
                    )
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text('Сохранить'),
          ),
      ],
    );
  }

  Widget _timeRow(
    String label,
    TimeOfDay? value,
    ValueChanged<TimeOfDay?> onChanged,
  ) {
    final timeStr = value != null
        ? '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}'
        : '--:--';
    return InkWell(
      onTap: widget.canEdit
          ? () async {
              final t = await _pickTime(value);
              if (t != null) onChanged(t);
            }
          : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppStyles.bgPage,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppStyles.border),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.textPrimary)),
            const Spacer(),
            Text(
              timeStr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppStyles.primary,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.access_time, size: 18, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _DigitalTimePicker extends StatefulWidget {
  final TimeOfDay initial;

  const _DigitalTimePicker({required this.initial});

  @override
  State<_DigitalTimePicker> createState() => _DigitalTimePickerState();
}

class _DigitalTimePickerState extends State<_DigitalTimePicker> {
  late int _hour;
  late int _minute;
  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;

  @override
  void initState() {
    super.initState();
    _hour = widget.initial.hour;
    _minute = widget.initial.minute;
    _hourCtrl = FixedExtentScrollController(initialItem: _hour);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 380,
        height: 460,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                'Выберите время',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  const Spacer(),
                  _wheel(
                    controller: _hourCtrl,
                    count: 24,
                    selected: _hour,
                    onChanged: (i) => setState(() => _hour = i),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ),
                  _wheel(
                    controller: _minuteCtrl,
                    count: 60,
                    selected: _minute,
                    onChanged: (i) => setState(() => _minute = i),
                  ),
                  const Spacer(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child:
                          const Text('Отмена', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                        context,
                        TimeOfDay(hour: _hour, minute: _minute),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppStyles.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Готово',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required ValueChanged<int> onChanged,
  }) {
    return SizedBox(
      width: 100,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: 64,
        diameterRatio: 1.4,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: onChanged,
        childDelegate: ListWheelChildBuilderDelegate(
          builder: (context, index) {
            if (index < 0 || index >= count) return null;
            final isSelected = index == selected;
            return Container(
              alignment: Alignment.center,
              child: Text(
                index.toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: isSelected ? 44 : 32,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppStyles.primary : Colors.grey.shade400,
                ),
              ),
            );
          },
          childCount: count,
        ),
      ),
    );
  }
}
