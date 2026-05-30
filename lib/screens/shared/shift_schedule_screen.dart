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
    const nameWidth = 140.0;
    const hoursWidth = 60.0;
    const minDayWidth = 90.0;
    final minTableWidth = nameWidth + hoursWidth + days.length * minDayWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        final targetWidth = constraints.maxWidth > minTableWidth
            ? constraints.maxWidth
            : minTableWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: SizedBox(
              width: targetWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                            width: nameWidth,
                            child: _headerCell('Мойщик')),
                        ...days.map((d) => Expanded(
                              child: _headerCell(
                                _dayLabel(d),
                                isWeekend: d.weekday >= 6,
                              ),
                            )),
                        SizedBox(
                            width: hoursWidth,
                            child: _headerCell('Часов')),
                      ],
                    ),
                    const Divider(height: 1),
                    ..._washers.map((w) {
                      var totalMinutes = 0;
                      final rowCells = days.map((d) {
                        final shift = _findShift(w.id!, d);
                        if (shift != null && shift.status == 'confirmed') {
                          totalMinutes += shift.durationMinutes;
                        }
                        return Expanded(
                          child: _shiftCell(w, d, shift),
                        );
                      }).toList();

                      return Row(
                        children: [
                          SizedBox(
                              width: nameWidth, child: _nameCell(w)),
                          ...rowCells,
                          SizedBox(
                              width: hoursWidth,
                              child: _hoursCell(totalMinutes)),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _headerCell(String text, {bool isWeekend = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: isWeekend ? AppStyles.danger.withValues(alpha: 0.08) : null,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isWeekend ? AppStyles.danger : AppStyles.textPrimary,
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Text(
        w.displayName,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        overflow: TextOverflow.ellipsis,
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
      label = '${shift.startTime}→${shift.endTime}';
      textColor = Colors.white;
    } else if (shift.status == 'rejected') {
      bgColor = AppStyles.danger;
      label = 'Отклонена';
      textColor = Colors.white;
    } else {
      bgColor = AppStyles.primary;
      label = '${shift.startTime}→${shift.endTime}';
      textColor = Colors.white;
    }

    return GestureDetector(
      onTap: () => _openEditor(washer, date, shift),
      child: Container(
        height: 56,
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isWeekend
                ? AppStyles.danger.withValues(alpha: 0.15)
                : Colors.grey.shade200,
          ),
        ),
        alignment: Alignment.center,
        child: label.isEmpty
            ? canEdit
                ? Icon(Icons.add, size: 16, color: Colors.grey.shade400)
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
                    ),
                  ),
                  if (shift?.status == 'pending')
                    const Text(
                      'Ожидает',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white,
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _hoursCell(int totalMinutes) {
    final hours = totalMinutes / 60;
    return Container(
      height: 56,
      alignment: Alignment.center,
      child: Text(
        hours.toStringAsFixed(1),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppStyles.textPrimary,
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
    return showModalBottomSheet<TimeOfDay>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DigitalTimePicker(initial: init),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('d MMMM, EEEE', 'ru_RU').format(widget.date);
    final canSave = _start != null && _end != null;

    return AlertDialog(
      title: Text(widget.washerName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(dateLabel, style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Начало'),
            trailing: Text(
              _start != null
                  ? '${_start!.hour.toString().padLeft(2, '0')}:${_start!.minute.toString().padLeft(2, '0')}'
                  : '--:--',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: widget.canEdit
                ? () async {
                    final t = await _pickTime(_start);
                    if (t != null) setState(() => _start = t);
                  }
                : null,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Конец'),
            trailing: Text(
              _end != null
                  ? '${_end!.hour.toString().padLeft(2, '0')}:${_end!.minute.toString().padLeft(2, '0')}'
                  : '--:--',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            onTap: widget.canEdit
                ? () async {
                    final t = await _pickTime(_end);
                    if (t != null) setState(() => _end = t);
                  }
                : null,
          ),
        ],
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
            child: const Text('Сохранить'),
          ),
      ],
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
    final size = MediaQuery.of(context).size;
    return Container(
      height: size.height * 0.55,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
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
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
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
                    child: const Text('Отмена',
                        style: TextStyle(fontSize: 16)),
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
                    child: const Text('Готово',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
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
