import 'package:flutter/material.dart';
import '../../app_styles.dart';
import '../../core/service_locator.dart';
import '../../models/car.dart';
import '../../services/api_service.dart';
import '../../services/car_catalog_service.dart';
import '../../utils/plate_formatter.dart';
import '../../widgets/car_autocomplete_field.dart';

class CarListScreen extends StatefulWidget {
  const CarListScreen({super.key});

  @override
  State<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends State<CarListScreen> {
  final _api = sl<ApiService>();
  List<Car> _cars = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCars();
  }

  Future<void> _loadCars() async {
    setState(() => _loading = true);
    final cars = await _api.getCars();
    if (mounted) {
      setState(() {
        _cars = cars;
        _loading = false;
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppStyles.danger : AppStyles.success,
    ));
  }

  Future<void> _deleteCar(Car car) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить автомобиль?'),
        content: Text('${car.displayName} · ${car.number}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyles.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await _api.deleteCar(car.id);
    if (ok) {
      _showSnack('Автомобиль удалён');
      await _loadCars();
    } else {
      _showSnack('Не удалось удалить', isError: true);
    }
  }

  void _showCarSheet({Car? car}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CarEditSheet(
        car: car,
        onSaved: () => _loadCars(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: theme.dividerColor),
        ),
        title: const Text('Мои автомобили',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCars,
              child: _cars.isEmpty
                  ? _EmptyState(onAdd: () => _showCarSheet())
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _cars.length,
                      itemBuilder: (_, i) {
                        final car = _cars[i];
                        return _CarCard(
                          car: car,
                          onTap: () => _showCarSheet(car: car),
                          onDelete: () => _deleteCar(car),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppStyles.primary,
        onPressed: () => _showCarSheet(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_car_outlined,
              size: 64, color: AppStyles.adaptiveTextMuted(context)),
          const SizedBox(height: 16),
          Text('Нет сохранённых автомобилей',
              style: TextStyle(
                  color: AppStyles.adaptiveTextSecondary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Добавьте первый автомобиль',
              style: TextStyle(
                  color: AppStyles.adaptiveTextMuted(context), fontSize: 13)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: AppStyles.primaryButton,
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Добавить автомобиль'),
          ),
        ],
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  final Car car;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CarCard({
    required this.car,
    required this.onTap,
    required this.onDelete,
  });

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
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppStyles.adaptivePrimaryBg(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.directions_car_outlined,
                      color: AppStyles.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              car.displayName,
                              style: TextStyle(
                                color: AppStyles.adaptiveTextPrimary(context),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (car.isPrimary) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppStyles.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('Основное',
                                  style: TextStyle(
                                      color: AppStyles.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        car.number.isNotEmpty ? car.number : 'Нет номера',
                        style: TextStyle(
                          color: car.number.isNotEmpty
                              ? AppStyles.adaptiveTextSecondary(context)
                              : AppStyles.adaptiveTextMuted(context),
                          fontSize: 13,
                          letterSpacing: car.number.isNotEmpty ? 1.2 : 0,
                          fontWeight: car.number.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: AppStyles.adaptiveTextMuted(context)),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CarEditSheet extends StatefulWidget {
  final Car? car;
  final VoidCallback onSaved;

  const _CarEditSheet({this.car, required this.onSaved});

  @override
  State<_CarEditSheet> createState() => _CarEditSheetState();
}

class _CarEditSheetState extends State<_CarEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _brandCtrl;
  late TextEditingController _modelCtrl;
  late TextEditingController _numberCtrl;
  String? _selectedBrand;
  bool _isPrimary = false;
  bool _saving = false;

  bool get _isEditing => widget.car != null;

  @override
  void initState() {
    super.initState();
    final car = widget.car;
    _brandCtrl = TextEditingController(text: car?.brand ?? '');
    _modelCtrl = TextEditingController(text: car?.model ?? '');
    _numberCtrl = TextEditingController(text: car?.number ?? '');
    _selectedBrand = car?.brand.isNotEmpty == true ? car!.brand : null;
    _isPrimary = car?.isPrimary ?? false;
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _numberCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final api = sl<ApiService>();
    final brand = _brandCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final number = _numberCtrl.text.trim().toUpperCase();

    Car? result;
    if (_isEditing) {
      result = await api.updateCar(
        widget.car!.id,
        brand: brand,
        model: model,
        number: number,
        isPrimary: _isPrimary,
      );
    } else {
      result = await api.createCar(
        brand: brand,
        model: model,
        number: number,
        isPrimary: _isPrimary,
      );
    }

    setState(() => _saving = false);
    if (mounted) {
      if (result != null) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(_isEditing ? 'Автомобиль обновлён' : 'Автомобиль добавлен'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppStyles.adaptiveBorder(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isEditing ? 'Редактировать авто' : 'Новый автомобиль',
              style: TextStyle(
                color: AppStyles.adaptiveTextPrimary(context),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            CarAutocompleteField(
              label: 'Марка',
              icon: Icons.directions_car_outlined,
              controller: _brandCtrl,
              optionsBuilder: (q) => sl<CarCatalogService>().searchBrands(q),
              onSelected: (brand) {
                setState(() => _selectedBrand = brand);
                _modelCtrl.clear();
              },
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите марку' : null,
            ),
            const SizedBox(height: 12),
            CarAutocompleteField(
              label: 'Модель',
              hint: _selectedBrand == null ? 'Сначала выберите марку' : null,
              icon: Icons.settings_outlined,
              controller: _modelCtrl,
              enabled: _selectedBrand != null,
              optionsBuilder: (q) {
                if (_selectedBrand == null) return [];
                return sl<CarCatalogService>().searchModels(_selectedBrand!, q);
              },
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Введите модель' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _numberCtrl,
              style: TextStyle(
                color: AppStyles.adaptiveTextPrimary(context),
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: _plateDecoration(),
              inputFormatters: [PlateInputFormatter()],
              validator: validatePlate,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: AppStyles.cardDecorationFor(context),
              child: SwitchListTile(
                title: Text('Основной автомобиль',
                    style: TextStyle(
                        color: AppStyles.adaptiveTextPrimary(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                subtitle: Text('Использовать по умолчанию при записи',
                    style: TextStyle(
                        color: AppStyles.adaptiveTextSecondary(context),
                        fontSize: 12)),
                value: _isPrimary,
                activeThumbColor: AppStyles.primary,
                onChanged: (v) => setState(() => _isPrimary = v),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: AppStyles.primaryButton,
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_isEditing ? 'Сохранить' : 'Добавить',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  InputDecoration _plateDecoration() {
    final base = AppStyles.inputDecorationFor(context, 'Гос. номер',
        hint: 'А000АА777', icon: Icons.pin_outlined);
    return base.copyWith(
      helperText: 'Формат: А000АА777',
      helperStyle: TextStyle(
          color: AppStyles.adaptiveTextSecondary(context), fontSize: 11),
    );
  }
}
