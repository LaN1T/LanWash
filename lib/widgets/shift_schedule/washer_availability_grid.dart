import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_styles.dart';
import '../../models/user.dart';
import '../../models/washer_availability.dart';

/// A 7-day availability editor for a single washer.
///
/// Tapping a day cycles: unknown -> available -> unavailable -> unknown.
/// The parent is responsible for persisting changes via [onSave] / [onReset].
class WasherAvailabilityGrid extends StatefulWidget {
  final User washer;
  final DateTime weekStart;
  final List<WasherAvailability> availability;
  final bool isEditable;
  final ValueChanged<List<WasherAvailability>>? onSave;
  final VoidCallback? onReset;

  const WasherAvailabilityGrid({
    super.key,
    required this.washer,
    required this.weekStart,
    required this.availability,
    this.isEditable = true,
    this.onSave,
    this.onReset,
  });

  @override
  State<WasherAvailabilityGrid> createState() => _WasherAvailabilityGridState();
}

class _WasherAvailabilityGridState extends State<WasherAvailabilityGrid> {
  late Map<String, String> _draft;

  @override
  void initState() {
    super.initState();
    _draft = _buildDraft(widget.availability);
  }

  @override
  void didUpdateWidget(covariant WasherAvailabilityGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.availability != oldWidget.availability ||
        widget.weekStart != oldWidget.weekStart) {
      _draft = _buildDraft(widget.availability);
    }
  }

  Map<String, String> _buildDraft(List<WasherAvailability> list) {
    return {for (final a in list) a.date: a.status};
  }

  List<DateTime> get _days =>
      List.generate(7, (i) => widget.weekStart.add(Duration(days: i)));

  String _fmt(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _nextStatus(String current) {
    switch (current) {
      case 'unknown':
        return 'available';
      case 'available':
        return 'unavailable';
      default:
        return 'unknown';
    }
  }

  void _cycle(DateTime day) {
    if (!widget.isEditable) return;
    final key = _fmt(day);
    setState(() {
      _draft[key] = _nextStatus(_draft[key] ?? 'unknown');
    });
  }

  void _markAllAvailable() {
    if (!widget.isEditable) return;
    setState(() {
      for (final day in _days) {
        _draft[_fmt(day)] = 'available';
      }
    });
  }

  void _reset() {
    if (!widget.isEditable) return;
    setState(() {
      for (final day in _days) {
        _draft.remove(_fmt(day));
      }
    });
    widget.onReset?.call();
  }

  void _save() {
    if (!widget.isEditable || widget.onSave == null) return;
    final entries = <WasherAvailability>[];
    final now = DateTime.now().toIso8601String();
    for (final day in _days) {
      final date = _fmt(day);
      final status = _draft[date] ?? 'unknown';
      if (status == 'available' || status == 'unavailable') {
        entries.add(WasherAvailability(
          id: 0,
          userId: widget.washer.id!,
          date: date,
          status: status,
          updatedAt: now,
        ));
      }
    }
    widget.onSave!(entries);
  }

  @override
  Widget build(BuildContext context) {
    final dayLabelFmt = DateFormat('E\nd', 'ru_RU');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: _days.map((day) {
            final label = dayLabelFmt.format(day);
            final isWeekend = day.weekday >= 6;
            return Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: Text(
                  label,
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
              ),
            );
          }).toList(),
        ),
        Row(
          children: _days.map((day) {
            final status = _draft[_fmt(day)] ?? 'unknown';
            return Expanded(
              child: GestureDetector(
                onTap: () => _cycle(day),
                child: Container(
                  height: 72,
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _bgColor(status, context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _borderColor(status, context),
                      width: status == 'unknown' ? 1 : 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: _statusIcon(status),
                ),
              ),
            );
          }).toList(),
        ),
        if (widget.isEditable) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _markAllAvailable,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Вся неделя доступна'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _reset,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Сбросить'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Сохранить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _bgColor(String status, BuildContext context) {
    switch (status) {
      case 'available':
        return AppStyles.success.withValues(alpha: 0.12);
      case 'unavailable':
        return AppStyles.danger.withValues(alpha: 0.12);
      default:
        return AppStyles.adaptiveCard(context);
    }
  }

  Color _borderColor(String status, BuildContext context) {
    switch (status) {
      case 'available':
        return AppStyles.success;
      case 'unavailable':
        return AppStyles.danger;
      default:
        return AppStyles.adaptiveBorder(context);
    }
  }

  Widget _statusIcon(String status) {
    switch (status) {
      case 'available':
        return const Icon(Icons.check_circle, color: AppStyles.success);
      case 'unavailable':
        return const Icon(Icons.cancel, color: AppStyles.danger);
      default:
        return Icon(
          Icons.help_outline,
          color: Colors.grey.shade400,
        );
    }
  }
}
