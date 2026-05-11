import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../app_styles.dart';
import '../models/service.dart';
import '../providers/app_provider.dart';

const _categories = [
  'Мойка кузова', 'Обработка стёкол', 'Защитные покрытия',
  'Уход за салоном', 'Специальные услуги', 'Детейлинг',
];

class AddEditServiceScreen extends StatefulWidget {
  final Service? service;
  const AddEditServiceScreen({super.key, this.service});
  @override State<AddEditServiceScreen> createState() => _State();
}

class _State extends State<AddEditServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durCtrl;
  late String _category;

  bool get _isEditing => widget.service != null;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameCtrl  = TextEditingController(text: s?.name        ?? '');
    _descCtrl  = TextEditingController(text: s?.description ?? '');
    _priceCtrl = TextEditingController(text: s != null ? '${s.price}' : '');
    _durCtrl   = TextEditingController(text: s != null ? '${s.durationMinutes}' : '');
    _category  = s?.category ?? _categories.first;
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose();
    _priceCtrl.dispose(); _durCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyles.background,
      appBar: AppBar(
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        title: Text(_isEditing ? 'Редактировать услугу' : 'Новая услуга'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(padding: AppStyles.pagePadding, children: [
          _label('Название и описание'),
          TextFormField(
            controller: _nameCtrl,
            decoration: AppStyles.inputDecoration('Название услуги', icon: Icons.label),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descCtrl,
            decoration: AppStyles.inputDecoration('Описание', icon: Icons.description),
            maxLines: 4,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите описание' : null,
          ),
          const SizedBox(height: 20),

          _label('Стоимость и длительность'),
          Row(children: [
            Expanded(child: TextFormField(
              controller: _priceCtrl,
              decoration: AppStyles.inputDecoration('Цена (₽)', icon: Icons.payments),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => (v == null || v.isEmpty) ? 'Введите цену' : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: TextFormField(
              controller: _durCtrl,
              decoration: AppStyles.inputDecoration('Время (мин)', icon: Icons.access_time),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) => (v == null || v.isEmpty) ? 'Введите время' : null,
            )),
          ]),
          const SizedBox(height: 20),

          _label('Категория'),
          Container(
            decoration: AppStyles.cardDecoration,
            child: Column(
              children: _categories.map((cat) => RadioListTile<String>(
                value: cat,
                groupValue: _category,
                onChanged: (v) => setState(() => _category = v!),
                title: Text(cat, style: AppStyles.bodyLarge),
                activeColor: AppStyles.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                dense: true,
              )).toList(),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: Text(_isEditing ? 'Сохранить изменения' : 'Добавить услугу'),
            style: AppStyles.primaryButton,
            onPressed: _save,
          ),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(text, style: AppStyles.label.copyWith(fontSize: 13, color: AppStyles.primary)),
  );

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<AppProvider>();

    if (_isEditing) {
      provider.updateService(widget.service!.copyWith(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: int.parse(_priceCtrl.text),
        durationMinutes: int.parse(_durCtrl.text),
        category: _category,
      ));
    } else {
      provider.addService(Service(
        id: 'svc_${DateTime.now().millisecondsSinceEpoch}',
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        price: int.parse(_priceCtrl.text),
        durationMinutes: int.parse(_durCtrl.text),
        category: _category,
      ));
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(_isEditing ? 'Услуга обновлена' : 'Услуга добавлена'),
      backgroundColor: AppStyles.success,
    ));
  }
}
