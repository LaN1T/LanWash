import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_styles.dart';
import '../../models/shift.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/shift_schedule/shift_analytics_header.dart';
import '../../widgets/shift_schedule/shift_filter_bar.dart';

import '../../widgets/shift_schedule/shift_requests_panel.dart';

class ShiftScheduleScreen extends StatefulWidget {
  const ShiftScheduleScreen({super.key});

  @override
  State<ShiftScheduleScreen> createState() => _ShiftScheduleScreenState();
}

/// A single shift cell in the weekly schedule table.
class ShiftCell extends StatelessWidget {
  final User washer;
  final DateTime date;
  final Shift? shift;
  final bool canEdit;
  final List<Shift> dayShifts;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;
  final VoidCallback? onPaste;
  final VoidCallback? onClear;

  const ShiftCell({
    super.key,
    required this.washer,
    required this.date,
    this.shift,
    required this.canEdit,
    this.dayShifts = const [],
    this.onTap,
    this.onCopy,
    this.onPaste,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isWeekend = date.weekday >= 6;
    final hasConflict = shift != null && _hasConflict(shift!, dayShifts);

    Color bgColor;
    String timeLabel;
    Color textColor;
    String? badge;

    if (shift == null) {
      bgColor = Colors.transparent;
      timeLabel = '';
      textColor = AppStyles.adaptiveTextSecondary(context);
    } else if (shift!.status == 'pending') {
      bgColor = AppStyles.warning;
      timeLabel = '${shift!.startTime}–${shift!.endTime}';
      textColor = Colors.white;
      badge = 'ожид.';
    } else if (shift!.status == 'rejected') {
      bgColor = AppStyles.danger;
      timeLabel = 'Откл.';
      textColor = Colors.white;
    } else {
      bgColor = AppStyles.primary;
      timeLabel = '${shift!.startTime}–${shift!.endTime}';
      textColor = Colors.white;
    }

    final child = Container(
      height: 72,
      margin: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasConflict
              ? AppStyles.danger
              : shift == null
                  ? (isWeekend
                      ? AppStyles.danger.withValues(alpha: 0.12)
                      : Colors.grey.shade200)
                  : Colors.transparent,
          width: hasConflict ? 2 : 1,
        ),
      ),
      alignment: Alignment.center,
      child: timeLabel.isEmpty
          ? canEdit
              ? Icon(Icons.add, size: 18, color: Colors.grey.shade300)
              : const SizedBox.shrink()
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timeLabel,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                if (badge != null)
                  Text(
                    badge,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                if (shift != null && shift!.status == 'confirmed')
                  Text(
                    '${shift!.durationMinutes ~/ 60} ч',
                    style: TextStyle(
                      fontSize: 9,
                      color: textColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
    );

    Widget cell = GestureDetector(
      onTap: onTap,
      onLongPress: _hasMenu ? () => _showMenu(context) : null,
      child: SizedBox(
        height: 72,
        child: Stack(
          children: [
            child,
            if (hasConflict)
              const Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: AppStyles.danger,
                ),
              ),
          ],
        ),
      ),
    );

    if (shift != null) {
      cell = Tooltip(
        message:
            '${shift!.startTime} – ${shift!.endTime} (${_statusLabel(shift!.status)})',
        child: cell,
      );
    }

    return cell;
  }

  bool get _hasMenu =>
      (shift != null && (onCopy != null || onClear != null)) ||
      (shift == null && onPaste != null);

  void _showMenu(BuildContext context) {
    final items = <PopupMenuEntry<VoidCallback>>[];
    if (shift != null && onCopy != null) {
      items.add(
        const PopupMenuItem(
          value: null,
          child: Row(
            children: [
              Icon(Icons.copy, size: 18),
              SizedBox(width: 8),
              Text('Копировать'),
            ],
          ),
        ),
      );
    }
    if (shift == null && onPaste != null) {
      items.add(
        const PopupMenuItem(
          value: null,
          child: Row(
            children: [
              Icon(Icons.paste, size: 18),
              SizedBox(width: 8),
              Text('Вставить'),
            ],
          ),
        ),
      );
    }
    if (shift != null && onClear != null) {
      items.add(
        const PopupMenuItem(
          value: null,
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 18, color: AppStyles.danger),
              SizedBox(width: 8),
              Text('Удалить', style: TextStyle(color: AppStyles.danger)),
            ],
          ),
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items.asMap().entries.map((e) {
            final label = switch (e.key) {
              0 => shift != null ? 'Копировать' : 'Вставить',
              _ => 'Удалить',
            };
            final action = switch (label) {
              'Копировать' => onCopy,
              'Вставить' => onPaste,
              _ => onClear,
            };
            return ListTile(
              leading: Icon(
                label == 'Копировать'
                    ? Icons.copy
                    : label == 'Вставить'
                        ? Icons.paste
                        : Icons.delete_outline,
                color: label == 'Удалить' ? AppStyles.danger : null,
              ),
              title: Text(
                label,
                style: TextStyle(
                  color: label == 'Удалить' ? AppStyles.danger : null,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                action?.call();
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'confirmed':
        return 'подтверждена';
      case 'pending':
        return 'на рассмотрении';
      case 'rejected':
        return 'отклонена';
      default:
        return status;
    }
  }

  static bool _hasConflict(Shift shift, List<Shift> dayShifts) {
    final shiftStart = _minutes(shift.startTime);
    final shiftEnd = _minutes(shift.endTime);
    for (final other in dayShifts) {
      if (other.id == shift.id) continue;
      final otherStart = _minutes(other.startTime);
      final otherEnd = _minutes(other.endTime);
      if (shiftStart < otherEnd && shiftEnd > otherStart) return true;
    }
    return false;
  }

  static bool hasConflict(Shift shift, List<Shift> dayShifts) =>
      _hasConflict(shift, dayShifts);

  static int _minutes(String t) {
    final p = t.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  static int minutes(String t) => _minutes(t);
}

/// Horizontal list of avatar circles for washers currently on duty.
class OnDutyAvatars extends StatelessWidget {
  final List<Map<String, dynamic>> currentShifts;
  final List<User> washers;
  final ValueChanged<int>? onTap;

  const OnDutyAvatars({
    super.key,
    required this.currentShifts,
    required this.washers,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (currentShifts.isEmpty) return const SizedBox.shrink();

    final userIds =
        currentShifts.map((s) => s['userId'] as int?).whereType<int>().toSet();
    final onDuty = washers.where((w) => userIds.contains(w.id)).toList();

    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        itemCount: onDuty.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, index) {
          final w = onDuty[index];
          final initial =
              w.displayName.isNotEmpty ? w.displayName[0].toUpperCase() : '?';
          return GestureDetector(
            onTap: () => onTap?.call(w.id!),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: AppStyles.primary,
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Popup menu for admin bulk approve/reject actions.
class BulkActionsMenu extends StatelessWidget {
  final VoidCallback onApproveAll;
  final VoidCallback onRejectAll;

  const BulkActionsMenu({
    super.key,
    required this.onApproveAll,
    required this.onRejectAll,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        if (value == 'approve') onApproveAll();
        if (value == 'reject') onRejectAll();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'approve',
          child: Text('Одобрить все заявки'),
        ),
        PopupMenuItem(
          value: 'reject',
          child: Text('Отклонить все заявки'),
        ),
      ],
    );
  }
}

class _ShiftScheduleScreenState extends State<ShiftScheduleScreen> {
  bool _loading = true;
  List<User> _washers = [];
  List<Shift> _shifts = [];
  List<Map<String, dynamic>> _currentShifts = [];
  late DateTime _weekStart;
  int? _highlightedWasherId;
  Shift? _copiedShift;
  List<Shift>? _copiedWeek;
  ShiftFilter _filter = ShiftFilter.all;

  static const int _targetWeeklyMinutesPerWasher = 40 * 60;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isWasher) {
        _jumpToMyNearestShiftWeek();
      } else {
        _loadData();
      }
    });
  }

  DateTime _mondayOf(DateTime date) {
    final wd = date.weekday;
    return DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: wd - 1));
  }

  Future<void> _jumpToMyNearestShiftWeek() async {
    final api = context.read<ApiService>();
    final myShifts = await api.getMyShifts();
    if (myShifts.isNotEmpty) {
      final now = DateTime.now();
      Shift? nearest;
      var minDiff = const Duration(days: 365);
      for (final s in myShifts) {
        final d = DateTime.parse(s.date);
        final diff = d.difference(now).abs();
        if (diff < minDiff) {
          minDiff = diff;
          nearest = s;
        }
      }
      if (nearest != null) {
        final d = DateTime.parse(nearest.date);
        setState(() => _weekStart = _mondayOf(d));
      }
    }
    if (mounted) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final api = context.read<ApiService>();
    final washers = await api.getWashers();
    final end = _weekStart.add(const Duration(days: 6));
    final fmt = DateFormat('yyyy-MM-dd');
    final shifts = await api.getShifts(fmt.format(_weekStart), fmt.format(end));
    final current = await api.getCurrentShifts();
    if (mounted) {
      setState(() {
        _washers = washers;
        _shifts = shifts;
        _currentShifts = current;
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
      return _shifts.firstWhere((s) => s.userId == userId && s.date == d);
    } catch (_) {
      return null;
    }
  }

  bool get _isAdmin {
    final auth = context.read<AuthProvider>();
    return auth.isAdmin;
  }

  bool get _isWasher {
    final auth = context.read<AuthProvider>();
    return auth.isWasher;
  }

  bool _canEdit(User washer) {
    if (_isAdmin) return true;
    final me = context.read<AuthProvider>().user;
    return me?.username == washer.username;
  }

  Future<void> _approveShiftFromPanel(Shift shift) async {
    final ok = await context.read<ApiService>().approveShift(shift.id);
    if (ok != null && mounted) {
      _showSnack('Смена одобрена');
      _loadData();
    }
  }

  Future<void> _rejectShiftFromPanel(Shift shift) async {
    final ok = await context.read<ApiService>().rejectShift(shift.id);
    if (ok != null && mounted) {
      _showSnack('Смена отклонена');
      _loadData();
    }
  }

  Future<void> _reopenShiftFromPanel(Shift shift) async {
    final ok = await context.read<ApiService>().reopenShift(shift.id);
    if (ok != null && mounted) {
      _showSnack('Смена возвращена на рассмотрение');
      _loadData();
    }
  }

  void _jumpToShift(Shift shift) {
    try {
      final washer = _washers.firstWhere((w) => w.id == shift.userId);
      setState(() {
        _highlightedWasherId = washer.id;
        _weekStart = _mondayOf(DateTime.parse(shift.date));
      });
      _loadData();
    } catch (_) {}
  }

  void _showRequestsBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, __) => Padding(
          padding: const EdgeInsets.all(16),
          child: ShiftRequestsPanel(
            shifts: _shifts,
            washers: _washers,
            onApprove: _approveShiftFromPanel,
            onReject: _rejectShiftFromPanel,
            onUndo: (shift, _) {
              Navigator.of(context).pop();
              _reopenShiftFromPanel(shift);
            },
            onJump: (shift) {
              Navigator.of(context).pop();
              _jumpToShift(shift);
            },
          ),
        ),
      ),
    );
  }

  List<User> get _visibleWashers {
    switch (_filter) {
      case ShiftFilter.mine:
        final me = context.read<AuthProvider>().user;
        return _washers.where((w) => w.username == me?.username).toList();
      case ShiftFilter.pending:
      case ShiftFilter.conflicts:
      case ShiftFilter.all:
        return _washers;
    }
  }

  List<Shift> get _confirmedShifts =>
      _shifts.where((s) => s.status == 'confirmed').toList();

  double get _totalConfirmedHours =>
      _confirmedShifts.fold<int>(0, (sum, s) => sum + s.durationMinutes) / 60.0;

  int get _pendingCount => _shifts.where((s) => s.status == 'pending').length;

  int get _conflictCount {
    var count = 0;
    final fmt = DateFormat('yyyy-MM-dd');
    for (final washer in _washers) {
      for (var i = 0; i < 7; i++) {
        final date = fmt.format(_weekStart.add(Duration(days: i)));
        final day = _shifts
            .where((s) => s.userId == washer.id && s.date == date)
            .toList();
        for (final shift in day) {
          if (ShiftCell.hasConflict(shift, day)) count++;
        }
      }
    }
    return count ~/ 2;
  }

  double? get _utilizationPercent {
    final availableMinutes = _washers.length * _targetWeeklyMinutesPerWasher;
    if (availableMinutes == 0) return null;
    final confirmedMinutes =
        _confirmedShifts.fold<int>(0, (sum, s) => sum + s.durationMinutes);
    return (confirmedMinutes / availableMinutes) * 100;
  }

  void _copyShift(Shift shift) {
    setState(() {
      _copiedShift = shift;
      _copiedWeek = null;
    });
    _showSnack('Смена скопирована');
  }

  void _copyWeek(int userId) {
    final weekShifts = _shifts.where((s) => s.userId == userId).toList();
    setState(() {
      _copiedWeek = weekShifts;
      _copiedShift = null;
    });
    _showSnack('Неделя скопирована');
  }

  Future<void> _pasteShift(User washer, DateTime date) async {
    if (_copiedShift == null) return;
    final fmt = DateFormat('yyyy-MM-dd');
    final result = await context.read<ApiService>().createShift(
          washer.id!,
          fmt.format(date),
          _copiedShift!.startTime,
          _copiedShift!.endTime,
        );
    if (result != null && mounted) {
      _showSnack('Смена вставлена');
      _loadData();
    }
  }

  Future<void> _pasteWeek(User washer) async {
    if (_copiedWeek == null || _copiedWeek!.isEmpty) return;
    final api = context.read<ApiService>();
    final fmt = DateFormat('yyyy-MM-dd');
    final baseMonday = _mondayOf(DateTime.parse(_copiedWeek!.first.date));
    final offsetDays = _weekStart.difference(baseMonday).inDays;

    for (final shift in _copiedWeek!) {
      final originalDate = DateTime.parse(shift.date);
      final targetDate = originalDate.add(Duration(days: offsetDays));
      await api.createShift(
        washer.id!,
        fmt.format(targetDate),
        shift.startTime,
        shift.endTime,
      );
    }
    if (mounted) {
      _showSnack('Неделя вставлена');
      _loadData();
    }
  }

  Future<void> _deleteShift(Shift shift) async {
    final ok = await context.read<ApiService>().deleteShift(shift.id);
    if (ok && mounted) {
      _showSnack('Смена удалена');
      _loadData();
    }
  }

  Future<void> _clearWeek(User washer) async {
    final canEdit = _canEdit(washer);
    if (!canEdit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить смены за неделю?'),
        content: const Text(
            'Все смены этого мойщика на текущей неделе будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить',
                style: TextStyle(color: AppStyles.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final api = context.read<ApiService>();
    final toDelete = _shifts.where((s) => s.userId == washer.id).toList();
    for (final shift in toDelete) {
      await api.deleteShift(shift.id);
    }
    _showSnack('Смены удалены');
    _loadData();
  }

  Future<void> _confirmBulkAction(String action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          action == 'approve'
              ? 'Одобрить все заявки?'
              : 'Отклонить все заявки?',
        ),
        content: const Text(
          'Это действие применится ко всем сменам со статусом "на рассмотрении" на текущей неделе.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Применить'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _applyBulkAction(action);
  }

  Future<void> _applyBulkAction(String action) async {
    final api = context.read<ApiService>();
    final pending = _shifts.where((s) => s.status == 'pending').toList();
    for (final shift in pending) {
      if (action == 'approve') {
        await api.approveShift(shift.id);
      } else {
        await api.rejectShift(shift.id);
      }
    }
    if (mounted) {
      _showSnack(
          action == 'approve' ? 'Все заявки одобрены' : 'Все заявки отклонены');
      _loadData();
    }
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
      await _deleteShift(existing);
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
    final fmt = DateFormat('d MMM', 'ru_RU');
    final weekLabel = '${fmt.format(_weekStart)} – ${fmt.format(weekEnd)}';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          children: [
            const Expanded(
              child: Text(
                'Расписание смен',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            OnDutyAvatars(
              currentShifts: _currentShifts,
              washers: _washers,
              onTap: (id) => setState(() => _highlightedWasherId = id),
            ),
          ],
        ),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
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
          if (_isAdmin && _pendingCount > 0) ...[
            TextButton.icon(
              onPressed: () => _confirmBulkAction('approve'),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Одобрить все'),
              style: TextButton.styleFrom(foregroundColor: AppStyles.success),
            ),
            TextButton.icon(
              onPressed: () => _confirmBulkAction('reject'),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Отклонить все'),
              style: TextButton.styleFrom(foregroundColor: AppStyles.danger),
            ),
          ],
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _washers.isEmpty
              ? const Center(child: Text('Нет мойщиков для отображения'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1100;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              ShiftAnalyticsHeader(
                                totalConfirmedHours: _totalConfirmedHours,
                                pendingCount: _pendingCount,
                                conflictCount: _conflictCount,
                                utilizationPercent: _utilizationPercent,
                              ),
                              ShiftFilterBar(
                                selected: _filter,
                                onChanged: (f) => setState(() => _filter = f),
                              ),
                              Expanded(child: _buildTable()),
                            ],
                          ),
                        ),
                        if (isWide)
                          ShiftRequestsPanel(
                            shifts: _shifts,
                            washers: _washers,
                            onApprove: _approveShiftFromPanel,
                            onReject: _rejectShiftFromPanel,
                            onUndo: (shift, _) => _reopenShiftFromPanel(shift),
                            onJump: _jumpToShift,
                          ),
                      ],
                    );
                  },
                ),
      floatingActionButton: _loading || _washers.isEmpty
          ? null
          : MediaQuery.sizeOf(context).width >= 1100
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => _showRequestsBottomSheet(context),
                  icon: const Icon(Icons.format_list_bulleted),
                  label: Text(
                    'Заявки${_pendingCount > 0 ? " ($_pendingCount)" : ""}',
                  ),
                ),
    );
  }

  Widget _buildTable() {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final fmt = DateFormat('yyyy-MM-dd');

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppStyles.adaptiveCard(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppStyles.adaptiveBorder(context)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              0: const FractionColumnWidth(0.15),
              for (var i = 0; i < days.length; i++)
                i + 1: const FractionColumnWidth(0.112),
              days.length + 1: const FractionColumnWidth(0.066),
            },
            border: TableBorder(
              horizontalInside:
                  BorderSide(color: AppStyles.adaptiveBorder(context)),
              verticalInside:
                  BorderSide(color: AppStyles.adaptiveBorder(context)),
            ),
            children: [
              // Header
              TableRow(
                decoration:
                    BoxDecoration(color: AppStyles.adaptiveBgMuted(context)),
                children: [
                  _headerCell('Мойщик', align: Alignment.centerLeft),
                  ...days.map(
                    (d) => _headerCell(_dayLabel(d), isWeekend: d.weekday >= 6),
                  ),
                  _headerCell('Часов'),
                ],
              ),
              // Rows
              ..._visibleWashers.map((w) {
                final highlight = _highlightedWasherId == w.id;
                var totalMinutes = 0;
                final shiftCells = days.map((d) {
                  final shift = _findShift(w.id!, d);
                  if (shift != null && shift.status == 'confirmed') {
                    totalMinutes += shift.durationMinutes;
                  }
                  final dayShifts = _shifts
                      .where((s) => s.userId == w.id && s.date == fmt.format(d))
                      .toList();
                  final hasConflict =
                      shift != null && ShiftCell.hasConflict(shift, dayShifts);
                  final matchesFilter = _filter == ShiftFilter.all ||
                      _filter == ShiftFilter.mine ||
                      (_filter == ShiftFilter.pending &&
                          shift?.status == 'pending') ||
                      (_filter == ShiftFilter.conflicts && hasConflict);

                  return _wrapHighlight(
                    highlight,
                    matchesFilter
                        ? ShiftCell(
                            washer: w,
                            date: d,
                            shift: shift,
                            canEdit: _canEdit(w),
                            dayShifts: dayShifts,
                            onTap: () => _openEditor(w, d, shift),
                            onCopy: shift != null
                                ? () => _copyShift(shift)
                                : null,
                            onPaste: shift == null && _copiedShift != null
                                ? () => _pasteShift(w, d)
                                : null,
                            onClear: shift != null
                                ? () => _deleteShift(shift)
                                : null,
                          )
                        : const SizedBox(height: 72),
                  );
                }).toList();

                return TableRow(
                  children: [
                    _wrapHighlight(
                      highlight,
                      _nameCell(w, canEdit: _canEdit(w)),
                    ),
                    ...shiftCells,
                    _wrapHighlight(
                      highlight,
                      _hoursCell(totalMinutes),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapHighlight(bool highlight, Widget child) {
    if (!highlight) return child;
    return Container(
      color: AppStyles.primary.withValues(alpha: 0.08),
      child: child,
    );
  }

  Widget _headerCell(
    String text, {
    bool isWeekend = false,
    Alignment align = Alignment.center,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      alignment: align,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isWeekend
              ? AppStyles.danger
              : AppStyles.adaptiveTextPrimary(context),
          height: 1.3,
        ),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final names = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return '${names[d.weekday - 1]}\n${d.day}';
  }

  Widget _nameCell(User w, {required bool canEdit}) {
    final cell = Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        w.displayName,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppStyles.adaptiveTextPrimary(context),
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      ),
    );

    if (!canEdit) return cell;

    return GestureDetector(
      onLongPress: () => _showNameCellMenu(w),
      child: cell,
    );
  }

  void _showNameCellMenu(User washer) {
    final hasWeekCopy = _copiedWeek != null && _copiedWeek!.isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Копировать неделю'),
              onTap: () {
                Navigator.pop(context);
                _copyWeek(washer.id!);
              },
            ),
            if (hasWeekCopy)
              ListTile(
                leading: const Icon(Icons.paste),
                title: const Text('Вставить неделю'),
                onTap: () {
                  Navigator.pop(context);
                  _pasteWeek(washer);
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.delete_outline, color: AppStyles.danger),
              title: const Text('Очистить неделю',
                  style: TextStyle(color: AppStyles.danger)),
              onTap: () {
                Navigator.pop(context);
                _clearWeek(washer);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _hoursCell(int totalMinutes) {
    final hours = totalMinutes / 60;
    final hasHours = totalMinutes > 0;
    final isOvertime = totalMinutes > _targetWeeklyMinutesPerWasher;
    final isNearLimit = !isOvertime &&
        totalMinutes >= (_targetWeeklyMinutesPerWasher * 0.8).round();
    return Container(
      height: 72,
      alignment: Alignment.center,
      child: Text(
        hours.toStringAsFixed(1),
        style: TextStyle(
          fontSize: 13,
          fontWeight: hasHours ? FontWeight.w700 : FontWeight.w600,
          color: isOvertime
              ? AppStyles.danger
              : isNearLimit
                  ? AppStyles.warning
                  : hasHours
                      ? AppStyles.primary
                      : AppStyles.adaptiveTextSecondary(context),
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
      backgroundColor: AppStyles.adaptiveCard(context),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(widget.washerName),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateLabel,
              style: TextStyle(
                fontSize: 14,
                color: AppStyles.adaptiveTextSecondary(context),
              ),
            ),
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
          color: AppStyles.adaptiveBgPage(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppStyles.adaptiveBorder(context)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppStyles.adaptiveTextPrimary(context),
              ),
            ),
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
          color: AppStyles.adaptiveCard(context),
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
                      child: const Text(
                        'Отмена',
                        style: TextStyle(fontSize: 16),
                      ),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
