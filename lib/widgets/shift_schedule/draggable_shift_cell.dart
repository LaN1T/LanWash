import 'package:flutter/material.dart';

import '../../app_styles.dart';
import '../../models/shift.dart';
import '../../models/user.dart';
import '../../screens/shared/shift_schedule_screen.dart';

/// Wraps [ShiftCell] with drag & drop affordances.
///
/// When [shift] is not null and [isDraggable] is true, the cell can be dragged.
/// When [shift] is null and [isDropTarget] is true, the cell accepts dropped
/// shifts and reports them via [onMove].
///
/// A filled cell is only a drag source; an empty cell is only a drop target.
/// This avoids nesting a [Draggable] inside a [DragTarget], which can trigger
/// framework element-lifecycle assertions.
class DraggableShiftCell extends StatelessWidget {
  final User washer;
  final DateTime date;
  final Shift? shift;
  final bool canEdit;
  final bool isDraggable;
  final bool isDropTarget;
  final List<Shift> dayShifts;
  final String? availabilityStatus;
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
    this.availabilityStatus,
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
      availabilityStatus: availabilityStatus,
      onTap: onTap,
      onCopy: onCopy,
      onPaste: onPaste,
      onClear: onClear,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (shift != null && isDraggable) {
      return Draggable<Shift>(
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
        child: _buildCell(),
      );
    }

    if (isDropTarget) {
      return DragTarget<Shift>(
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
            child: _buildCell(),
          );
        },
      );
    }

    return _buildCell();
  }
}
