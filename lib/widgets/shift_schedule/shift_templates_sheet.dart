import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app_styles.dart';
import '../../models/shift_template.dart';
import '../../models/user.dart';

class ShiftTemplatesSheet extends StatelessWidget {
  final List<ShiftTemplate> templates;
  final User? targetWasher;
  final DateTime weekStart;
  final VoidCallback onRefresh;
  final Future<void> Function(String name, List<ShiftTemplateSlot> slots) onSave;
  final Future<void> Function(ShiftTemplate template) onApply;
  final Future<void> Function(ShiftTemplate template) onDelete;
  final Future<void> Function(ShiftTemplate template, bool isDefault) onSetDefault;

  const ShiftTemplatesSheet({
    super.key,
    required this.templates,
    this.targetWasher,
    required this.weekStart,
    required this.onRefresh,
    required this.onSave,
    required this.onApply,
    required this.onDelete,
    required this.onSetDefault,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('d MMM', 'ru_RU');
    final weekEnd = weekStart.add(const Duration(days: 6));
    final weekLabel = '${fmt.format(weekStart)} – ${fmt.format(weekEnd)}';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Шаблоны недель',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _saveCurrentWeek(context),
                icon: const Icon(Icons.save, size: 18),
                label: const Text('Сохранить текущую'),
              ),
            ],
          ),
          Text(
            'Применить к неделе $weekLabel${targetWasher != null ? ' · ${targetWasher!.displayName}' : ''}',
            style: TextStyle(
              fontSize: 13,
              color: AppStyles.adaptiveTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: templates.isEmpty
                ? Center(
                    child: Text(
                      'Нет сохранённых шаблонов',
                      style: TextStyle(
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: templates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final t = templates[index];
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: t.isDefault
                              ? const Icon(Icons.star, color: AppStyles.warning)
                              : const Icon(Icons.calendar_view_week),
                          title: Text(t.name),
                          subtitle: Text('${t.slots.length} смен'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow),
                                tooltip: 'Применить',
                                onPressed: () async {
                                  await onApply(t);
                                  if (context.mounted) Navigator.pop(context);
                                },
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) async {
                                  if (value == 'default') {
                                    await onSetDefault(t, !t.isDefault);
                                    onRefresh();
                                  } else if (value == 'delete') {
                                    await onDelete(t);
                                    onRefresh();
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem(
                                    value: 'default',
                                    child: Text(t.isDefault
                                        ? 'Снять по умолчанию'
                                        : 'По умолчанию'),
                                  ),
                                  const PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Удалить'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCurrentWeek(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _SaveTemplateDialog(),
    );
    if (name == null || name.trim().isEmpty) return;
    // Slots are built by the host screen from the currently displayed week.
    await onSave(name.trim(), const []);
  }
}

class _SaveTemplateDialog extends StatefulWidget {
  const _SaveTemplateDialog();

  @override
  State<_SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<_SaveTemplateDialog> {
  final _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Сохранить шаблон'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Название шаблона',
          hintText: 'Например, Стандартная неделя',
        ),
        maxLength: 120,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
