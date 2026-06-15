import 'package:flutter/material.dart';
import '../../app_styles.dart';

enum ShiftFilter { all, mine, pending, conflicts }

class ShiftFilterBar extends StatelessWidget {
  final ShiftFilter selected;
  final ValueChanged<ShiftFilter> onChanged;

  const ShiftFilterBar({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _labels = <ShiftFilter, String>{
    ShiftFilter.all: 'Все',
    ShiftFilter.mine: 'Только я',
    ShiftFilter.pending: 'Заявки',
    ShiftFilter.conflicts: 'Конфликты',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: ShiftFilter.values.map((filter) {
          final isSelected = selected == filter;
          return ChoiceChip(
            label: Text(_labels[filter]!),
            selected: isSelected,
            selectedColor: AppStyles.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: isSelected
                  ? AppStyles.primary
                  : AppStyles.adaptiveTextPrimary(context),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected
                    ? AppStyles.primary
                    : AppStyles.adaptiveBorder(context),
              ),
            ),
            backgroundColor: AppStyles.adaptiveCard(context),
            onSelected: (_) => onChanged(filter),
          );
        }).toList(),
      ),
    );
  }
}
