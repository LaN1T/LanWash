import 'package:flutter/material.dart';

import '../../app_styles.dart';
import '../../models/shift.dart';
import '../../models/user.dart';
import '../../screens/shared/shift_schedule_screen.dart';

/// Wraps [ShiftCell] with drag & drop affordances.
///
/// When [shift] is not null and [isDraggable] is true, the cell can be dragged.
/// When [isDropTarget] is true, the cell accepts dropped shifts and reports
/// them via [onMove].
class DraggableShiftCell extends StatelessWidget {
  final User washer;
  final DateTime date;
  final Shift? shift;
  final bool canEdit;
  final bool isDraggable;
  final bool isDropTarget;
  final List<Shift> dayShifts;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;
  final VoidCallback? onPaste;
  final VoidCallback? onClear;
  final ValueChanged<Shift>? onMove;

  const DraggableShiftCell({
    super.key,
    required this.washer,
    required this.date,
    this.shift,
    required this.canEdit,
    this.isDraggable = false,
    this.isDropTarget = false,
    this.dayShifts = const [],
    this.onTap,
    this.onCopy,
    this.onPaste,
    this.onClear,
    this.onMove,
  });

  Widget _buildCell() {
    return ShiftCell(
      washer: washer,
      date: date,
      shift: shift,
      canEdit: canEdit,
      dayShifts: dayShifts,
      onTap: onTap,
      onCopy: onCopy,
      onPaste: onPaste,
      onClear: onClear,
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget cell = _buildCell();

    if (isDraggable && shift != null) {
      cell = Draggable<Shift>(
        data: shift,
        feedback: Material(
          color: Colors.transparent,
          child: Container(
            width: 100,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppStyles.primary,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              '${shift!.startTime}–${shift!.endTime}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.35,
          child: _buildCell(),
        ),
        child: _buildCell(),
      );
    }

    if (isDropTarget) {
      cell = DragTarget<Shift>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) => onMove?.call(details.data),
        builder: (context, candidateData, rejectedData) {
          final active = candidateData.isNotEmpty;
          return Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: active
                  ? Border.all(color: AppStyles.primary, width: 2)
                  : null,
            ),
            child: cell,
          );
        },
      );
    }

    return cell;
  }
}
