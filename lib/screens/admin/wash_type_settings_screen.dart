import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/wash_type.dart';
import '../../providers/app_provider.dart';

class WashTypeSettingsScreen extends StatelessWidget {
  const WashTypeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final washTypes = [...provider.washTypes]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        title: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppStyles.primaryGradient,
            ),
            child: const Icon(Icons.settings, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text('Настройки мойки',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        ]),
      ),
      body: washTypes.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: AppStyles.primary))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: washTypes.length,
              itemBuilder: (ctx, i) => _WashTypeCard(washType: washTypes[i]),
            ),
    );
  }
}

class _WashTypeCard extends StatelessWidget {
  final WashType washType;
  const _WashTypeCard({required this.washType});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final includedNames = washType.includedExtraIds
        .map((id) => provider.services
            .firstWhere((s) => s.id == id, orElse: () => _stubService(id))
            .name)
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppStyles.cardDecorationFor(context),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppStyles.adaptivePrimaryBg(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.local_car_wash,
                color: AppStyles.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(washType.name,
                  style: TextStyle(
                      color: AppStyles.adaptiveTextPrimary(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text('ID: ${washType.id} · ${washType.code}',
                  style: AppStyles.bodySmall),
            ],
          )),
          IconButton(
            icon: const Icon(Icons.edit, color: AppStyles.primary),
            onPressed: () => _openEditor(context, washType),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _Stat(Icons.payments_outlined, 'Цена', '${washType.basePrice} ₽'),
          const SizedBox(width: 24),
          _Stat(Icons.access_time_rounded, 'Время', washType.durationLabel),
        ]),
        if (washType.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(washType.description,
              style: AppStyles.bodyMedium.copyWith(height: 1.4)),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppStyles.adaptiveInnerCard(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Включённые доп. услуги',
                style: TextStyle(
                    color: AppStyles.adaptiveTextSecondary(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            if (includedNames.isEmpty)
              Text('—',
                  style: AppStyles.bodyMedium.copyWith(
                      color: AppStyles.adaptiveTextSecondary(context)))
            else
              Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: includedNames
                      .map((n) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppStyles.adaptiveCard(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(n,
                                style: TextStyle(
                                    color:
                                        AppStyles.adaptiveTextPrimary(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500)),
                          ))
                      .toList()),
          ]),
        ),
      ]),
    );
  }

  static dynamic _stubService(String id) {
    // Используем модель Service — импорт не нужен, т.к. передаём .name через dynamic
    return _NameHolder(id);
  }

  void _openEditor(BuildContext context, WashType wt) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WashTypeEditor(washType: wt),
    );
  }
}

class _NameHolder {
  final String name;
  _NameHolder(this.name);
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  // ignore: prefer_const_constructors_in_immutables
  _Stat(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: AppStyles.adaptiveTextSecondary(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(icon, size: 14, color: AppStyles.primary),
            const SizedBox(width: 4),
            Text(value,
                style: const TextStyle(
                    color: AppStyles.primary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
          ]),
        ],
      );
}

class _WashTypeEditor extends StatefulWidget {
  final WashType washType;
  const _WashTypeEditor({required this.washType});

  @override
  State<_WashTypeEditor> createState() => _WashTypeEditorState();
}

class _WashTypeEditorState extends State<_WashTypeEditor> {
  late TextEditingController _nameCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _durationCtrl;
  late Set<String> _includedIds;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.washType.name);
    _descCtrl = TextEditingController(text: widget.washType.description);
    _priceCtrl =
        TextEditingController(text: widget.washType.basePrice.toString());
    _durationCtrl =
        TextEditingController(text: widget.washType.durationMinutes.toString());
    _includedIds = Set.from(widget.washType.includedExtraIds);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final extras = provider.services
        .where((s) => s.category != 'Акции')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
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
                  child: Text('Изменить: ${widget.washType.name}',
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
                TextField(
                  controller: _nameCtrl,
                  decoration: AppStyles.inputDecorationFor(context, 'Название',
                      icon: Icons.label_outline),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration:
                      AppStyles.inputDecorationFor(context, 'Описание', icon: Icons.notes),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: TextField(
                    controller: _priceCtrl,
                    keyboardType: TextInputType.number,
                    decoration: AppStyles.inputDecorationFor(context, 'Цена (₽)',
                        icon: Icons.payments_outlined),
                  )),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    decoration: AppStyles.inputDecorationFor(context, 'Время (мин)',
                        icon: Icons.access_time_rounded),
                  )),
                ]),
                const SizedBox(height: 20),
                Text('Включённые доп. услуги',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppStyles.adaptiveTextPrimary(context))),
                const SizedBox(height: 8),
                Container(
                  decoration: AppStyles.cardDecorationFor(context),
                  child: Column(
                    children: extras
                        .map((s) => CheckboxListTile(
                              value: _includedIds.contains(s.id),
                              onChanged: (v) => setState(() {
                                v!
                                    ? _includedIds.add(s.id)
                                    : _includedIds.remove(s.id);
                              }),
                              title: Text(s.name,
                                  style: AppStyles.bodyLarge.copyWith(
                                      color: AppStyles.adaptiveTextPrimary(
                                          context))),
                              subtitle: Text(
                                  '+${s.price} ₽ · ${s.durationLabel}',
                                  style: AppStyles.bodySmall.copyWith(
                                      color: AppStyles.adaptiveTextSecondary(
                                          context))),
                              activeColor: AppStyles.primary,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              dense: true,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 20),
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

  Future<void> _save() async {
    final price = int.tryParse(_priceCtrl.text.trim()) ?? 0;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 30;
    if (_nameCtrl.text.trim().isEmpty || price <= 0 || duration <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Заполните все поля корректно'),
        backgroundColor: AppStyles.danger,
      ));
      return;
    }

    setState(() => _saving = true);
    final updated = widget.washType.copyWith(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      basePrice: price,
      durationMinutes: duration,
      includedExtraIds: _includedIds.toList(),
    );
    final ok = await context.read<AppProvider>().updateWashType(updated);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Тип мойки обновлён'),
        backgroundColor: AppStyles.success,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Не удалось сохранить'),
        backgroundColor: AppStyles.danger,
      ));
    }
  }
}
