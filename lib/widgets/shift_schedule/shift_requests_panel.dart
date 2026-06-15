import 'package:flutter/material.dart';
import '../../app_styles.dart';
import '../../models/shift.dart';
import '../../models/user.dart';
import 'shift_request_card.dart';

class ShiftRequestsPanel extends StatelessWidget {
  final List<Shift> shifts;
  final List<User> washers;
  final void Function(Shift shift) onApprove;
  final void Function(Shift shift) onReject;
  final void Function(Shift shift, String previousStatus) onUndo;
  final void Function(Shift shift) onJump;

  const ShiftRequestsPanel({
    super.key,
    required this.shifts,
    required this.washers,
    required this.onApprove,
    required this.onReject,
    required this.onUndo,
    required this.onJump,
  });

  User? _washerFor(int userId) {
    try {
      return washers.firstWhere((w) => w.id == userId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = shifts.where((s) => s.status == 'pending').toList();
    final approved = shifts.where((s) => s.status == 'confirmed').toList();
    final rejected = shifts.where((s) => s.status == 'rejected').toList();

    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: AppStyles.adaptiveBgPage(context),
        border: Border(
          left: BorderSide(color: AppStyles.adaptiveBorder(context)),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(
            context,
            title: 'На рассмотрении',
            count: pending.length,
            color: AppStyles.warning,
            shifts: pending,
            actionBuilder: (s) => {
              'onApprove': () => onApprove(s),
              'onReject': () => onReject(s),
              'onJump': () => onJump(s),
            },
          ),
          const SizedBox(height: 24),
          _section(
            context,
            title: 'Одобрено',
            count: approved.length,
            color: AppStyles.success,
            shifts: approved,
            actionBuilder: (s) => {
              'onUndo': () => onUndo(s, 'confirmed'),
              'onJump': () => onJump(s),
            },
          ),
          const SizedBox(height: 24),
          _section(
            context,
            title: 'Отклонено',
            count: rejected.length,
            color: AppStyles.danger,
            shifts: rejected,
            actionBuilder: (s) => {
              'onUndo': () => onUndo(s, 'rejected'),
              'onJump': () => onJump(s),
            },
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required int count,
    required Color color,
    required List<Shift> shifts,
    required Map<String, VoidCallback?> Function(Shift shift) actionBuilder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppStyles.adaptiveTextPrimary(context),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (shifts.isEmpty)
          Text(
            'Нет смен',
            style: TextStyle(
              fontSize: 13,
              color: AppStyles.adaptiveTextSecondary(context),
            ),
          )
        else
          ...shifts.map((s) {
            final washer = _washerFor(s.userId);
            if (washer == null) return const SizedBox.shrink();
            final actions = actionBuilder(s);
            return ShiftRequestCard(
              shift: s,
              washer: washer,
              status: s.status,
              onApprove: actions['onApprove'],
              onReject: actions['onReject'],
              onUndo: actions['onUndo'],
              onJump: actions['onJump'],
            );
          }),
      ],
    );
  }
}
