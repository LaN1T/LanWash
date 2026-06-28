import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../core/service_locator.dart';
import '../../models/subscription_plan.dart';
import '../../models/wash_type.dart';
import '../../providers/catalog_provider.dart';
import '../../services/api_service.dart';

class SubscriptionPlanSettingsScreen extends StatefulWidget {
  const SubscriptionPlanSettingsScreen({super.key});

  @override
  State<SubscriptionPlanSettingsScreen> createState() =>
      _SubscriptionPlanSettingsScreenState();
}

class _SubscriptionPlanSettingsScreenState
    extends State<SubscriptionPlanSettingsScreen> {
  List<SubscriptionPlan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await sl<ApiService>().getAdminSubscriptionPlans();
    if (mounted) {
      setState(() {
        _plans = list..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _loading = false;
      });
    }
  }

  Future<void> _delete(SubscriptionPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить абонемент?'),
        content: Text('План «${plan.name}» будет удалён безвозвратно.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppStyles.danger, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await sl<ApiService>().deleteSubscriptionPlan(plan.id);
    if (!mounted) return;
    if (ok) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Абонемент удалён'),
        backgroundColor: AppStyles.success,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Не удалось удалить абонемент'),
        backgroundColor: AppStyles.danger,
      ));
    }
  }

  void _openEditor({SubscriptionPlan? plan}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlanEditor(
        plan: plan,
        onSaved: _load,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        title: const Text('Готовые абонементы',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppStyles.primary))
          : RefreshIndicator(
              onRefresh: _load,
              color: AppStyles.primary,
              child: _plans.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.card_membership_outlined,
                                    size: 56,
                                    color: AppStyles.adaptiveTextMuted(context)),
                                const SizedBox(height: 16),
                                Text(
                                  'Нет готовых абонементов',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: AppStyles.adaptiveTextSecondary(
                                        context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _plans.length,
                      itemBuilder: (ctx, i) => _PlanCard(
                        plan: _plans[i],
                        onTap: () => _openEditor(plan: _plans[i]),
                        onDelete: () => _delete(_plans[i]),
                      ),
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PlanCard({
    required this.plan,
    required this.onTap,
    required this.onDelete,
  });

  String _subtitle() {
    if (plan.isPackage) {
      return '${plan.washCount} моек · скидка ${plan.discountPercent}%';
    }
    return '${plan.unlimitedDays} дней безлимита · скидка ${plan.discountPercent}%';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.cardDecorationFor(context),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: plan.isActive
                            ? AppStyles.primary.withValues(alpha: 0.12)
                            : AppStyles.adaptiveBgMuted(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        plan.isActive ? 'Активен' : 'Неактивен',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: plan.isActive
                              ? AppStyles.primary
                              : AppStyles.adaptiveTextMuted(context),
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppStyles.danger),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _subtitle(),
                  style: TextStyle(
                    fontSize: 13,
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                ),
                if (plan.description != null && plan.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      plan.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanEditor extends StatefulWidget {
  final SubscriptionPlan? plan;
  final VoidCallback onSaved;

  const _PlanEditor({this.plan, required this.onSaved});

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late TextEditingController _codeCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _washCountCtrl;
  late TextEditingController _unlimitedDaysCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _sortCtrl;
  late bool _isActive;
  late String _type;
  final Map<String, int> _washTypePrices = {};
  bool _saving = false;

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _codeCtrl = TextEditingController(text: plan?.code ?? '');
    _nameCtrl = TextEditingController(text: plan?.name ?? '');
    _descCtrl = TextEditingController(text: plan?.description ?? '');
    _washCountCtrl =
        TextEditingController(text: plan?.washCount?.toString() ?? '');
    _unlimitedDaysCtrl =
        TextEditingController(text: plan?.unlimitedDays?.toString() ?? '');
    _discountCtrl =
        TextEditingController(text: (plan?.discountPercent ?? 0).toString());
    _sortCtrl =
        TextEditingController(text: (plan?.sortOrder ?? 0).toString());
    _isActive = plan?.isActive ?? true;
    _type = plan?.type ?? 'package';
    if (plan?.washTypePrices != null) {
      _washTypePrices.addAll(plan!.washTypePrices!);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _washCountCtrl.dispose();
    _unlimitedDaysCtrl.dispose();
    _discountCtrl.dispose();
    _sortCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    if (name.isEmpty || (!_isEditing && code.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Заполните обязательные поля'),
        backgroundColor: AppStyles.danger,
      ));
      return;
    }

    final discount = int.tryParse(_discountCtrl.text.trim()) ?? 0;
    final sortOrder = int.tryParse(_sortCtrl.text.trim()) ?? 0;
    final washCount = int.tryParse(_washCountCtrl.text.trim());
    final unlimitedDays = int.tryParse(_unlimitedDaysCtrl.text.trim());

    final body = <String, dynamic>{
      'name': name,
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'discountPercent': discount,
      'sortOrder': sortOrder,
      'isActive': _isActive,
    };

    if (_type == 'package') {
      body['washCount'] = washCount;
      body['unlimitedDays'] = null;
      body['washTypePrices'] = null;
    } else {
      body['unlimitedDays'] = unlimitedDays;
      body['washCount'] = null;
      if (_washTypePrices.isNotEmpty) {
        body['washTypePrices'] = _washTypePrices;
      }
    }

    setState(() => _saving = true);
    final api = sl<ApiService>();
    final ok = _isEditing
        ? (await api.updateSubscriptionPlan(widget.plan!.id, body)) != null
        : (await api.createSubscriptionPlan({...body, 'code': code, 'type': _type})) != null;

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Не удалось сохранить абонемент'),
        backgroundColor: AppStyles.danger,
      ));
    }
  }

  void _editWashTypePrices(List<WashType> washTypes) {
    showDialog(
      context: context,
      builder: (ctx) => _WashTypePricesDialog(
        washTypes: washTypes,
        prices: _washTypePrices,
        onChanged: (prices) {
          setState(() {
            _washTypePrices.clear();
            _washTypePrices.addAll(prices);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final washTypes = context.watch<CatalogProvider>().washTypes;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: AppStyles.adaptiveCard(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppStyles.adaptiveBorder(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Expanded(
                  child: Text(
                      _isEditing ? 'Изменить абонемент' : 'Новый абонемент',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600))),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _saving ? null : () => Navigator.pop(context),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(20),
              children: [
                if (!_isEditing) ...[
                  TextField(
                    controller: _codeCtrl,
                    decoration: AppStyles.inputDecorationFor(
                        context, 'Код (латиница)',
                        icon: Icons.code),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _nameCtrl,
                  decoration: AppStyles.inputDecorationFor(
                      context, 'Название',
                      icon: Icons.label_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: AppStyles.inputDecorationFor(
                      context, 'Описание',
                      icon: Icons.notes),
                ),
                const SizedBox(height: 16),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'package', label: Text('Пакет моек')),
                    ButtonSegment(
                        value: 'unlimited', label: Text('Безлимитка')),
                  ],
                  selected: {_type},
                  onSelectionChanged: _isEditing
                      ? null
                      : (set) {
                          if (set.isNotEmpty) {
                            setState(() => _type = set.first);
                          }
                        },
                ),
                const SizedBox(height: 12),
                if (_type == 'package')
                  TextField(
                    controller: _washCountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: AppStyles.inputDecorationFor(
                        context, 'Количество моек',
                        icon: Icons.format_list_numbered),
                  )
                else
                  TextField(
                    controller: _unlimitedDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: AppStyles.inputDecorationFor(
                        context, 'Дней действия',
                        icon: Icons.calendar_today_outlined),
                  ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _discountCtrl,
                      keyboardType: TextInputType.number,
                      decoration: AppStyles.inputDecorationFor(
                          context, 'Скидка %',
                          icon: Icons.percent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _sortCtrl,
                      keyboardType: TextInputType.number,
                      decoration: AppStyles.inputDecorationFor(
                          context, 'Порядок',
                          icon: Icons.sort),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Активен'),
                  activeThumbColor: AppStyles.primary,
                  contentPadding: EdgeInsets.zero,
                ),
                if (_type == 'unlimited') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Цены по типам мойки',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppStyles.adaptiveTextPrimary(context),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _editWashTypePrices(washTypes),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Изменить'),
                      ),
                    ],
                  ),
                  if (_washTypePrices.isEmpty)
                    Text(
                      'Не заданы',
                      style: TextStyle(
                        color: AppStyles.adaptiveTextSecondary(context),
                        fontSize: 13,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _washTypePrices.entries.map((e) {
                        final wt = washTypes.firstWhere(
                          (w) => w.id == e.key,
                          orElse: () => WashType(
                            id: e.key,
                            name: e.key,
                            code: e.key,
                            description: '',
                            basePrice: 0,
                            durationMinutes: 0,
                            includedExtraIds: const [],
                            sortOrder: 0,
                          ),
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppStyles.adaptiveInnerCard(context),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${wt.name}: ${e.value} ₽',
                            style: TextStyle(
                              color: AppStyles.adaptiveTextPrimary(context),
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Сохранение...' : 'Сохранить'),
                    style: AppStyles.primaryButton,
                    onPressed: _saving ? null : _save,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _WashTypePricesDialog extends StatefulWidget {
  final List<WashType> washTypes;
  final Map<String, int> prices;
  final ValueChanged<Map<String, int>> onChanged;

  const _WashTypePricesDialog({
    required this.washTypes,
    required this.prices,
    required this.onChanged,
  });

  @override
  State<_WashTypePricesDialog> createState() => _WashTypePricesDialogState();
}

class _WashTypePricesDialogState extends State<_WashTypePricesDialog> {
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final wt in widget.washTypes)
        wt.id: TextEditingController(
          text: widget.prices[wt.id]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Цены по типам мойки'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.washTypes.length,
          itemBuilder: (ctx, i) {
            final wt = widget.washTypes[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(child: Text(wt.name)),
                  SizedBox(
                    width: 100,
                    child: TextField(
                      controller: _controllers[wt.id],
                      keyboardType: TextInputType.number,
                      decoration: AppStyles.inputDecorationFor(
                          context, '₽'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.primary,
              foregroundColor: Colors.white),
          onPressed: () {
            final result = <String, int>{};
            for (final entry in _controllers.entries) {
              final price = int.tryParse(entry.value.text.trim());
              if (price != null && price > 0) {
                result[entry.key] = price;
              }
            }
            widget.onChanged(result);
            Navigator.pop(context);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}
