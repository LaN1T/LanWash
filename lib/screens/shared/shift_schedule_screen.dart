import 'dart:async';

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
import '../../widgets/shift_schedule/shift_templates_sheet.dart';
import '../../widgets/shift_schedule/draggable_shift_cell.dart';
import '../../widgets/shift_schedule/washer_availability_grid.dart';
import '../../models/shift_template.dart';
import '../../models/washer_availability.dart';
import '../../models/shift_load_report.dart';
import '../../widgets/shift_schedule/shift_analytics_view.dart';

enum ShiftScheduleMode { shifts, availability, analytics }

class ShiftScheduleScreen extends StatefulWidget {
  final ShiftScheduleMode initialMode;
  const ShiftScheduleScreen(
      {super.key, this.initialMode = ShiftScheduleMode.shifts});

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
  final String? availabilityStatus;
  final bool isPast;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;
  final VoidCallback? onPaste;
  final VoidCallback? onClear;
  final VoidCallback? onCopyDay;
  final VoidCallback? onPasteDay;

  const ShiftCell({
    super.key,
    required this.washer,
    required this.date,
    this.shift,
    required this.canEdit,
    this.dayShifts = const [],
    this.availabilityStatus,
    this.isPast = false,
    this.onTap,
    this.onCopy,
    this.onPaste,
    this.onClear,
    this.onCopyDay,
    this.onPasteDay,
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
      bgColor = AppStyles.warning.withValues(alpha: isPast ? 0.85 : 1.0);
      timeLabel = '${shift!.startTime}–${shift!.endTime}';
      textColor = Colors.white.withValues(alpha: isPast ? 0.95 : 1.0);
      badge = 'ожид.';
    } else if (shift!.status == 'rejected') {
      bgColor = AppStyles.danger.withValues(alpha: isPast ? 0.85 : 1.0);
      timeLabel = 'Откл.';
      textColor = Colors.white.withValues(alpha: isPast ? 0.95 : 1.0);
    } else {
      bgColor = AppStyles.primary.withValues(alpha: isPast ? 0.85 : 1.0);
      timeLabel = '${shift!.startTime}–${shift!.endTime}';
      textColor = Colors.white.withValues(alpha: isPast ? 0.95 : 1.0);
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
            if (availabilityStatus == 'available')
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppStyles.success,
                    shape: BoxShape.circle,
                  ),
                ),
              )
            else if (availabilityStatus == 'unavailable')
              Positioned(
                top: 4,
                left: 4,
                right: 4,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppStyles.danger,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
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
      (shift == null && onPaste != null) ||
      onCopyDay != null ||
      onPasteDay != null;

  void _showMenu(BuildContext context) {
    final entries =
        <({String label, IconData icon, Color? color, VoidCallback? action})>[];
    if (shift != null && onCopy != null) {
      entries.add((
        label: 'Копировать',
        icon: Icons.copy,
        color: null,
        action: onCopy,
      ));
    }
    if (shift == null && onPaste != null) {
      entries.add((
        label: 'Вставить',
        icon: Icons.paste,
        color: null,
        action: onPaste,
      ));
    }
    if (onCopyDay != null) {
      entries.add((
        label: 'Копировать день',
        icon: Icons.copy_all,
        color: null,
        action: onCopyDay,
      ));
    }
    if (onPasteDay != null) {
      entries.add((
        label: 'Вставить день',
        icon: Icons.paste,
        color: null,
        action: onPasteDay,
      ));
    }
    if (shift != null && onClear != null) {
      entries.add((
        label: 'Удалить',
        icon: Icons.delete_outline,
        color: AppStyles.danger,
        action: onClear,
      ));
    }

    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: entries.map((e) {
            return ListTile(
              leading: Icon(e.icon, color: e.color),
              title: Text(e.label, style: TextStyle(color: e.color)),
              onTap: () {
                Navigator.pop(context);
                e.action?.call();
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
  String? _loadError;
  List<User> _washers = [];
  List<Shift> _shifts = [];
  List<Map<String, dynamic>> _currentShifts = [];
  late DateTime _weekStart;
  int? _highlightedWasherId;
  Shift? _copiedShift;
  List<Shift>? _copiedWeek;
  List<Shift>? _copiedDayShifts;
  DateTime? _copiedDayDate;
  ShiftFilter _filter = ShiftFilter.all;
  List<ShiftTemplate> _templates = [];
  late ShiftScheduleMode _mode;
  List<WasherAvailability> _availability = [];
  bool _availabilityLoading = false;
  ShiftLoadReport? _shiftLoadReport;
  bool _shiftLoadLoading = false;

  static const int _targetWeeklyMinutesPerWasher = 40 * 60;
  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    _weekStart = _mondayOf(DateTime.now());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isWasher) {
        unawaited(_jumpToMyNearestShiftWeek());
      } else {
        unawaited(_loadData());
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
    try {
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
    } catch (e, st) {
      debugPrint('ShiftSchedule: failed to load nearest shift week: $e\n$st');
    }
    if (mounted) await _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = context.read<ApiService>();
      final end = _weekStart.add(const Duration(days: 6));

      final washers = await api.getWashers();
      List<Shift> shifts = [];
      List<Map<String, dynamic>> current = [];

      if (_mode == ShiftScheduleMode.shifts) {
        final results = await Future.wait([
          api.getShifts(_dateFmt.format(_weekStart), _dateFmt.format(end)),
          api.getCurrentShifts(),
        ]);
        shifts = results[0] as List<Shift>;
        current = results[1] as List<Map<String, dynamic>>;
      }

      if (_mode != ShiftScheduleMode.analytics) {
        await _loadAvailability(washers);
      }

      if (_mode == ShiftScheduleMode.analytics) {
        await _loadShiftLoadReport();
      }

      if (mounted) {
        setState(() {
          _washers = washers;
          _shifts = shifts;
          _currentShifts = current;
          _loading = false;
        });
      }

      if (_mode == ShiftScheduleMode.shifts) {
        await _loadTemplates();
      }
    } catch (e, st) {
      debugPrint('ShiftSchedule: _loadData failed: $e\n$st');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _loadAvailability(List<User> washers) async {
    if (washers.isEmpty) {
      if (mounted) {
        setState(() {
          _availability = [];
          _availabilityLoading = false;
        });
      }
      return;
    }

    setState(() => _availabilityLoading = true);

    final api = context.read<ApiService>();
    final end = _weekStart.add(const Duration(days: 6));

    final userIds = <int>[];
    if (_mode == ShiftScheduleMode.availability) {
      userIds.addAll(washers.map((w) => w.id!).whereType<int>());
    } else if (_isAdmin) {
      userIds.addAll(washers.map((w) => w.id!).whereType<int>());
    }

    try {
      final results = await Future.wait(
        userIds.map(
          (id) => api.getWasherAvailability(
            id,
            _dateFmt.format(_weekStart),
            _dateFmt.format(end),
          ),
        ),
      );
      final all = results.expand((list) => list).toList();
      if (mounted) {
        setState(() {
          _availability = all;
          _availabilityLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('ShiftSchedule: failed to load availability: $e\n$st');
      if (mounted) setState(() => _availabilityLoading = false);
    }
  }

  Future<void> _loadShiftLoadReport() async {
    if (!_isAdmin) return;
    setState(() => _shiftLoadLoading = true);
    try {
      final end = _weekStart.add(const Duration(days: 6));
      final report = await context.read<ApiService>().getShiftLoadReport(
            _dateFmt.format(_weekStart),
            _dateFmt.format(end),
          );
      if (mounted) {
        setState(() {
          _shiftLoadReport = report;
          _shiftLoadLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('ShiftSchedule: failed to load shift load report: $e\n$st');
      if (mounted) setState(() => _shiftLoadLoading = false);
    }
  }

  String? _availabilityStatus(int userId, DateTime date) {
    final dateStr = _dateFmt.format(date);
    for (final a in _availability) {
      if (a.userId == userId && a.date == dateStr) {
        return a.status;
      }
    }
    return null;
  }

  void _changeWeek(int delta) {
    setState(() => _weekStart = _weekStart.add(Duration(days: 7 * delta)));
    unawaited(_loadData());
  }

  Shift? _findShift(int userId, DateTime date) {
    final d = _dateFmt.format(date);
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
      await _loadData();
    }
  }

  Future<void> _rejectShiftFromPanel(Shift shift) async {
    final ok = await context.read<ApiService>().rejectShift(shift.id);
    if (ok != null && mounted) {
      _showSnack('Смена отклонена');
      await _loadData();
    }
  }

  Future<void> _reopenShiftFromPanel(Shift shift) async {
    final ok = await context.read<ApiService>().reopenShift(shift.id);
    if (ok != null && mounted) {
      _showSnack('Смена возвращена на рассмотрение');
      await _loadData();
    }
  }

  Future<void> _handleShiftMove(
      Shift moved, User targetWasher, DateTime targetDate) async {
    final targetDateStr = _dateFmt.format(targetDate);

    // No-op drop on the same cell.
    if (moved.userId == targetWasher.id && moved.date == targetDateStr) {
      return;
    }

    final existing = _findShift(targetWasher.id!, targetDate);
    if (existing != null && existing.id != moved.id) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Перезаписать смену?'),
          content: const Text(
              'В целевой ячейке уже есть смена. Продолжить и заменить её?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Перезаписать',
                  style: TextStyle(color: AppStyles.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final result = await context
        .read<ApiService>()
        .moveShift(moved.id, targetWasher.id!, targetDateStr);
    if (result != null && mounted) {
      _showSnack('Смена перемещена');
      await _loadData();
    } else if (mounted) {
      _showSnack('Не удалось переместить смену', isError: true);
    }
  }

  void _jumpToShift(Shift shift) {
    try {
      final washer = _washers.firstWhere((w) => w.id == shift.userId);
      setState(() {
        _highlightedWasherId = washer.id;
        _weekStart = _mondayOf(DateTime.parse(shift.date));
      });
      unawaited(_loadData());
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

  void _openTemplatesSheet() {
    final target = _effectiveTargetWasher;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, __) => ShiftTemplatesSheet(
          templates: _templates,
          targetWasher: target,
          weekStart: _weekStart,
          onRefresh: _loadTemplates,
          onSave: (name, _) => _saveCurrentWeekAsTemplate(name),
          onApply: (template) => _applyTemplate(template, target),
          onDelete: (template) => _deleteTemplate(template),
          onSetDefault: (template, isDefault) =>
              _setDefaultTemplate(template, isDefault),
        ),
      ),
    );
  }

  User? get _selectedWasher {
    if (_highlightedWasherId != null) {
      try {
        return _washers.firstWhere((w) => w.id == _highlightedWasherId);
      } catch (_) {}
    }
    return null;
  }

  User? get _effectiveTargetWasher {
    if (_selectedWasher != null) return _selectedWasher;
    if (_isWasher) {
      final me = context.read<AuthProvider>().user;
      try {
        return _washers.firstWhere((w) => w.username == me?.username);
      } catch (_) {}
    }
    return null;
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await context.read<ApiService>().getShiftTemplates();
      if (mounted) setState(() => _templates = templates);
    } catch (e, st) {
      debugPrint('ShiftSchedule: failed to load templates: $e\n$st');
    }
  }

  Future<void> _saveCurrentWeekAsTemplate(String name) async {
    final washer = _effectiveTargetWasher;
    if (washer == null) {
      _showSnack('Выберите мойщика (тап по строке)');
      return;
    }

    final slots = _shifts.where((s) => s.userId == washer.id).map((s) {
      final date = DateTime.parse(s.date);
      return ShiftTemplateSlot(
        weekday: date.weekday,
        startTime: s.startTime,
        endTime: s.endTime,
      );
    }).toList()
      ..sort((a, b) => a.weekday.compareTo(b.weekday));

    if (slots.isEmpty) {
      _showSnack('У выбранного мойщика нет смен на текущей неделе');
      return;
    }

    final api = context.read<ApiService>();
    final template = await api.createShiftTemplate(
      ShiftTemplate(
        id: 0,
        ownerUsername: '',
        name: name,
        isDefault: false,
        slots: slots,
      ),
    );
    if (template != null && mounted) {
      _showSnack('Шаблон сохранён');
      await _loadTemplates();
    }
  }

  Future<void> _applyTemplate(ShiftTemplate template, User? target) async {
    final washer = target ?? _selectedWasher;
    if (washer == null) {
      _showSnack('Выберите мойщика');
      return;
    }

    final count = await context.read<ApiService>().applyShiftTemplate(
          template.id,
          weekStart: _dateFmt.format(_weekStart),
          targetUserId: washer.id,
        );
    if (mounted) {
      _showSnack(
          count > 0 ? 'Применено $count смен' : 'Не удалось применить шаблон');
      await _loadData();
    }
  }

  Future<void> _deleteTemplate(ShiftTemplate template) async {
    final ok =
        await context.read<ApiService>().deleteShiftTemplate(template.id);
    if (ok && mounted) {
      _showSnack('Шаблон удалён');
      await _loadTemplates();
    }
  }

  Future<void> _setDefaultTemplate(
      ShiftTemplate template, bool isDefault) async {
    final updated = await context.read<ApiService>().updateShiftTemplate(
          template.copyWith(isDefault: isDefault),
        );
    if (updated != null && mounted) {
      _showSnack(
          isDefault ? 'Шаблон по умолчанию установлен' : 'По умолчанию снят');
      await _loadTemplates();
    }
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

    for (final washer in _washers) {
      for (var i = 0; i < 7; i++) {
        final date = _dateFmt.format(_weekStart.add(Duration(days: i)));
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
    final api = context.read<ApiService>();
    final targetDateStr = _dateFmt.format(date);

    final existing = _findShift(washer.id!, date);
    if (existing != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Перезаписать смену?'),
          content: const Text('В этой ячейке уже есть смена. Заменить её?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Перезаписать',
                  style: TextStyle(color: AppStyles.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await api.deleteShift(existing.id);
    }

    final result = await api.createShift(
      washer.id!,
      targetDateStr,
      _copiedShift!.startTime,
      _copiedShift!.endTime,
    );
    if (result != null && mounted) {
      _showSnack('Смена вставлена');
      await _loadData();
    }
  }

  Future<void> _pasteWeek(User washer) async {
    if (_copiedWeek == null || _copiedWeek!.isEmpty) return;
    final api = context.read<ApiService>();
    final baseMonday = _mondayOf(DateTime.parse(_copiedWeek!.first.date));
    final offsetDays = _weekStart.difference(baseMonday).inDays;
    final weekDates = List.generate(
      7,
      (i) => _dateFmt.format(_weekStart.add(Duration(days: i))),
    );

    final existing = _shifts
        .where((s) => s.userId == washer.id && weekDates.contains(s.date))
        .toList();
    if (existing.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Заменить смены недели?'),
          content: const Text(
              'На текущей неделе уже есть смены этого мойщика. Заменить их?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Заменить',
                  style: TextStyle(color: AppStyles.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      for (final s in existing) {
        await api.deleteShift(s.id);
      }
    }

    for (final shift in _copiedWeek!) {
      final originalDate = DateTime.parse(shift.date);
      final targetDate = originalDate.add(Duration(days: offsetDays));
      await api.createShift(
        washer.id!,
        _dateFmt.format(targetDate),
        shift.startTime,
        shift.endTime,
      );
    }
    if (mounted) {
      _showSnack('Неделя вставлена');
      await _loadData();
    }
  }

  void _copyDay(User washer, DateTime date) {
    final dayShifts = _shifts
        .where((s) => s.userId == washer.id && s.date == _dateFmt.format(date))
        .toList();
    setState(() {
      _copiedDayShifts = dayShifts;
      _copiedDayDate = date;
      _copiedShift = null;
      _copiedWeek = null;
    });
    final dayLabel = DateFormat('d MMM', 'ru_RU').format(_copiedDayDate!);
    _showSnack('День $dayLabel скопирован');
  }

  Future<void> _pasteDay(User washer, DateTime date) async {
    if (_copiedDayShifts == null || _copiedDayShifts!.isEmpty) return;
    final api = context.read<ApiService>();
    final targetDateStr = _dateFmt.format(date);

    final existing = _shifts
        .where((s) => s.userId == washer.id && s.date == targetDateStr)
        .toList();
    if (existing.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Заменить смены дня?'),
          content: const Text(
              'В этот день уже есть смены. Заменить их скопированными?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Заменить',
                  style: TextStyle(color: AppStyles.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      for (final s in existing) {
        await api.deleteShift(s.id);
      }
    }

    for (final shift in _copiedDayShifts!) {
      await api.createShift(
        washer.id!,
        targetDateStr,
        shift.startTime,
        shift.endTime,
      );
    }
    if (mounted) {
      _showSnack('День вставлен');
      await _loadData();
    }
  }

  Future<void> _duplicateShift(Shift shift) async {
    final nextDate = DateTime.parse(shift.date).add(const Duration(days: 1));
    final nextDateStr = _dateFmt.format(nextDate);

    final existing = _findShift(shift.userId, nextDate);
    if (existing != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Перезаписать смену?'),
          content: const Text(
              'На следующий день уже есть смена. Продолжить и заменить её?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Перезаписать',
                  style: TextStyle(color: AppStyles.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await context.read<ApiService>().deleteShift(existing.id);
      if (!mounted) return;
    }

    final result = await context.read<ApiService>().createShift(
          shift.userId,
          nextDateStr,
          shift.startTime,
          shift.endTime,
        );
    if (result != null && mounted) {
      _showSnack('Смена продублирована');
      await _loadData();
    }
  }

  Future<void> _deleteShift(Shift shift) async {
    final ok = await context.read<ApiService>().deleteShift(shift.id);
    if (ok && mounted) {
      _showSnack('Смена удалена');
      await _loadData();
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
    await _loadData();
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
      await _loadData();
    }
  }

  Future<void> _saveAvailability(
      User washer, List<WasherAvailability> entries) async {
    final ok = await context
        .read<ApiService>()
        .updateWasherAvailability(washer.id!, entries);
    if (mounted) {
      _showSnack(
          ok.isNotEmpty ? 'Доступность сохранена' : 'Не удалось сохранить');
      await _loadData();
    }
  }

  Future<void> _resetAvailability(User washer) async {
    final ok = await context.read<ApiService>().deleteWasherAvailability(
          washer.id!,
          _dateFmt.format(_weekStart),
          _dateFmt.format(_weekStart.add(const Duration(days: 6))),
        );
    if (mounted) {
      _showSnack(ok ? 'Доступность сброшена' : 'Не удалось сбросить');
      await _loadData();
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

    final availabilityStatus = _availabilityStatus(washer.id!, date);

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
        availabilityStatus: availabilityStatus,
        onDuplicate: existing != null ? () => _duplicateShift(existing) : null,
      ),
    );
    if (result == null) return;

    if (result.delete && existing != null) {
      await _deleteShift(existing);
      return;
    }

    if (result.duplicate && existing != null) {
      await _duplicateShift(existing);
      return;
    }

    if (result.start != null && result.end != null) {
      final startStr =
          '${result.start!.hour.toString().padLeft(2, '0')}:${result.start!.minute.toString().padLeft(2, '0')}';
      final endStr =
          '${result.end!.hour.toString().padLeft(2, '0')}:${result.end!.minute.toString().padLeft(2, '0')}';
      final shift = await api.createShift(
        washer.id!,
        _dateFmt.format(date),
        startStr,
        endStr,
      );
      if (shift != null && mounted) {
        final msg = _isAdmin
            ? 'Смена сохранена'
            : 'Заявка на смену отправлена администратору';
        _showSnack(msg);
        await _loadData();
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
    final weekLabel =
        '${_dateFmt.format(_weekStart)} – ${_dateFmt.format(weekEnd)}';

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
          TextButton.icon(
            onPressed: _openTemplatesSheet,
            icon: const Icon(Icons.calendar_view_week, size: 18),
            label: const Text('Шаблоны'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppStyles.danger, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Не удалось загрузить расписание:\n$_loadError',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
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
                                  _buildModeToggle(),
                                  Expanded(
                                    child: _buildShiftsViewOrAvailability(),
                                  ),
                                ],
                              ),
                            ),
                            if (isWide)
                              ShiftRequestsPanel(
                                shifts: _shifts,
                                washers: _washers,
                                onApprove: _approveShiftFromPanel,
                                onReject: _rejectShiftFromPanel,
                                onUndo: (shift, _) =>
                                    _reopenShiftFromPanel(shift),
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

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayStr = _dateFmt.format(today);

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
                    (d) => _headerCell(
                      _dayLabel(d),
                      isWeekend: d.weekday >= 6,
                      isToday: _dateFmt.format(d) == todayStr,
                    ),
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
                      .where((s) =>
                          s.userId == w.id && s.date == _dateFmt.format(d))
                      .toList();
                  final hasConflict =
                      shift != null && ShiftCell.hasConflict(shift, dayShifts);
                  final availabilityStatus = _availabilityStatus(w.id!, d);
                  final matchesFilter = _filter == ShiftFilter.all ||
                      _filter == ShiftFilter.mine ||
                      (_filter == ShiftFilter.pending &&
                          shift?.status == 'pending') ||
                      (_filter == ShiftFilter.conflicts && hasConflict);
                  final isPast = d.isBefore(today);
                  final isToday = _dateFmt.format(d) == todayStr;

                  return _wrapHighlight(
                    highlight,
                    Container(
                      color: isToday
                          ? AppStyles.primary.withValues(alpha: 0.08)
                          : null,
                      child: matchesFilter
                          ? DraggableShiftCell(
                              washer: w,
                              date: d,
                              shift: shift,
                              canEdit: _canEdit(w),
                              isDraggable: _isAdmin && shift != null,
                              isDropTarget: _isAdmin,
                              dayShifts: dayShifts,
                              availabilityStatus: availabilityStatus,
                              isPast: isPast,
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
                              onCopyDay: () => _copyDay(w, d),
                              onPasteDay: _copiedDayShifts != null
                                  ? () => _pasteDay(w, d)
                                  : null,
                              onMove: (moved) => _handleShiftMove(moved, w, d),
                            )
                          : const SizedBox(height: 72),
                    ),
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

  Widget _buildModeToggle() {
    final modes = _isAdmin
        ? ShiftScheduleMode.values
        : [ShiftScheduleMode.shifts, ShiftScheduleMode.availability];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Center(
        child: ToggleButtons(
          isSelected: modes.map((m) => _mode == m).toList(),
          onPressed: (index) {
            final newMode = modes[index];
            if (newMode != _mode) {
              setState(() => _mode = newMode);
              unawaited(_loadData());
            }
          },
          borderRadius: BorderRadius.circular(12),
          selectedColor: Colors.white,
          fillColor: AppStyles.primary,
          color: AppStyles.adaptiveTextPrimary(context),
          children: modes.map((m) {
            final label = switch (m) {
              ShiftScheduleMode.shifts => 'Смены',
              ShiftScheduleMode.availability => 'Доступность',
              ShiftScheduleMode.analytics => 'Аналитика',
            };
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(label),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildShiftsViewOrAvailability() {
    if (_mode == ShiftScheduleMode.shifts) return _buildShiftsView();
    if (_mode == ShiftScheduleMode.availability) {
      return _buildAvailabilityView();
    }
    return _buildAnalyticsView();
  }

  Widget _buildAnalyticsView() {
    if (_shiftLoadLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final report = _shiftLoadReport;
    if (report == null) {
      return const Center(child: Text('Не удалось загрузить аналитику'));
    }
    return ShiftAnalyticsView(
      report: report,
    );
  }

  Widget _buildShiftsView() {
    return Column(
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
    );
  }

  Widget _buildAvailabilityView() {
    if (_availabilityLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final targets =
        _isAdmin ? _washers : _washers.where((w) => _canEdit(w)).toList();

    if (targets.isEmpty) {
      return const Center(child: Text('Нет мойщиков для отображения'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: targets.length,
      itemBuilder: (context, index) {
        final w = targets[index];
        final list = _availability.where((a) => a.userId == w.id).toList();
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  w.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                WasherAvailabilityGrid(
                  washer: w,
                  weekStart: _weekStart,
                  availability: list,
                  isEditable: _canEdit(w),
                  onSave: (entries) => _saveAvailability(w, entries),
                  onReset: () => _resetAvailability(w),
                ),
              ],
            ),
          ),
        );
      },
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
    bool isToday = false,
    Alignment align = Alignment.center,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      alignment: align,
      color: isToday ? AppStyles.primary.withValues(alpha: 0.08) : null,
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
      onTap: _isAdmin ? () => _openAvailabilityEditor(w) : null,
      onLongPress: () => _showNameCellMenu(w),
      child: cell,
    );
  }

  void _openAvailabilityEditor(User washer) {
    final washerAvailability =
        _availability.where((a) => a.userId == washer.id).toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.4,
        maxChildSize: 0.8,
        expand: false,
        builder: (_, __) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Доступность: ${washer.displayName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: WasherAvailabilityGrid(
                  washer: washer,
                  weekStart: _weekStart,
                  availability: washerAvailability,
                  isEditable: _canEdit(washer),
                  onSave: (entries) => _saveAvailability(washer, entries),
                  onReset: () => _resetAvailability(washer),
                ),
              ),
            ],
          ),
        ),
      ),
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
  final bool duplicate;

  _EditResult({
    this.start,
    this.end,
    this.delete = false,
    this.duplicate = false,
  });
}

class _ShiftDialog extends StatefulWidget {
  final String washerName;
  final DateTime date;
  final Shift? existing;
  final TimeOfDay? start;
  final TimeOfDay? end;
  final bool canEdit;
  final String? availabilityStatus;
  final VoidCallback? onDuplicate;

  const _ShiftDialog({
    required this.washerName,
    required this.date,
    this.existing,
    this.start,
    this.end,
    required this.canEdit,
    this.availabilityStatus,
    this.onDuplicate,
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
            if (widget.availabilityStatus == 'unavailable') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppStyles.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppStyles.danger.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppStyles.danger, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Мойщик отметил этот день как недоступный. Создать смену всё равно?',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
        if (widget.existing != null && widget.canEdit)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _EditResult(duplicate: true)),
            child: const Text('Дублировать'),
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
