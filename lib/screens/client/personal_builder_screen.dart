import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/service.dart';
import '../../models/wash_type.dart';
import '../../services/api_service.dart';
import 'subscription_checkout_screen.dart';

class PersonalBuilderScreen extends StatefulWidget {
  const PersonalBuilderScreen({super.key});

  @override
  State<PersonalBuilderScreen> createState() => _PersonalBuilderScreenState();
}

class _PersonalBuilderScreenState extends State<PersonalBuilderScreen> {
  List<WashType> _washTypes = [];
  List<Service> _extras = [];
  bool _loading = true;

  String? _selectedWashTypeId;
  final Set<String> _selectedExtraIds = {};
  int _washCount = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    final results = await Future.wait([api.getWashTypes(), api.getServices()]);
    if (mounted) {
      setState(() {
        _washTypes = results[0] as List<WashType>
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _extras = (results[1] as List<Service>)
            .where((s) => s.category != 'Акции')
            .toList()
          ..sort((a, b) => a.price.compareTo(b.price));
        if (_washTypes.isNotEmpty) {
          _selectedWashTypeId = _washTypes.first.id;
        }
        _loading = false;
      });
    }
  }

  WashType? get _selectedWashType {
    return _washTypes.where((w) => w.id == _selectedWashTypeId).firstOrNull;
  }

  int get _singlePrice {
    final wt = _selectedWashType;
    if (wt == null) return 0;
    final extrasPrice = _extras
        .where((e) => _selectedExtraIds.contains(e.id))
        .fold(0, (sum, e) => sum + e.price);
    return wt.basePrice + extrasPrice;
  }

  int get _discountPercent {
    if (_washCount >= 20) return 15;
    if (_washCount >= 10) return 10;
    if (_washCount >= 5) return 5;
    return 0;
  }

  int get _totalPrice {
    return _singlePrice * _washCount * (100 - _discountPercent) ~/ 100;
  }

  int get _originalPrice => _singlePrice * _washCount;

  void _changeCount(int delta) {
    setState(() {
      _washCount = (_washCount + delta).clamp(1, 99);
    });
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
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        title: const Text('Персональный абонемент',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppStyles.primary))
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: AppStyles.pagePadding,
                    children: [
                      _sectionLabel(context, 'Тип мойки'),
                      const SizedBox(height: 12),
                      ..._washTypes.map((wt) => _WashTypeTile(
                            washType: wt,
                            selected: _selectedWashTypeId == wt.id,
                            onTap: () => setState(
                                () => _selectedWashTypeId = wt.id),
                          )),
                      const SizedBox(height: 24),
                      _sectionLabel(context, 'Дополнительные услуги'),
                      const SizedBox(height: 12),
                      if (_extras.isEmpty)
                        Text(
                          'Нет доступных дополнительных услуг',
                          style: TextStyle(
                            color: AppStyles.adaptiveTextSecondary(context),
                          ),
                        )
                      else
                        ..._extras.map((e) => _ExtraTile(
                              service: e,
                              selected: _selectedExtraIds.contains(e.id),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedExtraIds.add(e.id);
                                  } else {
                                    _selectedExtraIds.remove(e.id);
                                  }
                                });
                              },
                            )),
                      const SizedBox(height: 24),
                      _sectionLabel(context, 'Количество моек'),
                      const SizedBox(height: 12),
                      _CountStepper(
                        count: _washCount,
                        onDecrement: () => _changeCount(-1),
                        onIncrement: () => _changeCount(1),
                      ),
                      const SizedBox(height: 24),
                      _TotalCard(
                        singlePrice: _singlePrice,
                        count: _washCount,
                        discountPercent: _discountPercent,
                        totalPrice: _totalPrice,
                        originalPrice: _originalPrice,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppStyles.adaptiveCard(context),
                    border: Border(
                        top: BorderSide(color: AppStyles.adaptiveBorder(context))),
                  ),
                  child: SafeArea(
                    child: ElevatedButton(
                      onPressed: _selectedWashType == null
                          ? null
                          : () {
                              final wt = _selectedWashType!;
                              final selectedExtras = _extras
                                  .where((e) =>
                                      _selectedExtraIds.contains(e.id))
                                  .map((e) => e.id)
                                  .toList();
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          SubscriptionCheckoutScreen.personal(
                                            name:
                                                'Персональный пакет «${wt.name}»',
                                            washTypeId: wt.id,
                                            washTypeName: wt.name,
                                            selectedExtras: selectedExtras,
                                            washCount: _washCount,
                                            price: _totalPrice,
                                            originalPrice: _originalPrice,
                                          )));
                            },
                      style: AppStyles.primaryButton.copyWith(
                        minimumSize: const WidgetStatePropertyAll(
                            Size(double.infinity, 52)),
                      ),
                      child: Text('Перейти к оплате ($_totalPrice ₽)'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Text(text,
      style: TextStyle(
          color: AppStyles.adaptiveTextSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1));
}

class _WashTypeTile extends StatelessWidget {
  final WashType washType;
  final bool selected;
  final VoidCallback onTap;

  const _WashTypeTile({
    required this.washType,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: selected
            ? AppStyles.primary.withValues(alpha: 0.08)
            : AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppStyles.primary : AppStyles.adaptiveBorder(context),
        ),
      ),
      child: RadioListTile<String>(
        value: washType.id,
        groupValue: selected ? washType.id : null,
        onChanged: (_) => onTap(),
        activeColor: AppStyles.primary,
        title: Text(
          washType.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppStyles.adaptiveTextPrimary(context),
          ),
        ),
        subtitle: Text(
          '${washType.basePrice} ₽',
          style: TextStyle(
            fontSize: 13,
            color: AppStyles.adaptiveTextSecondary(context),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ExtraTile extends StatelessWidget {
  final Service service;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  const _ExtraTile({
    required this.service,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: CheckboxListTile(
        value: selected,
        onChanged: onChanged,
        activeColor: AppStyles.primary,
        title: Text(
          service.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppStyles.adaptiveTextPrimary(context),
          ),
        ),
        subtitle: Text(
          '${service.price} ₽',
          style: TextStyle(
            fontSize: 13,
            color: AppStyles.adaptiveTextSecondary(context),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _CountStepper extends StatelessWidget {
  final int count;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _CountStepper({
    required this.count,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: count > 1 ? onDecrement : null,
            icon: const Icon(Icons.remove),
            color: AppStyles.primary,
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppStyles.adaptiveTextPrimary(context),
            ),
          ),
          IconButton(
            onPressed: count < 99 ? onIncrement : null,
            icon: const Icon(Icons.add),
            color: AppStyles.primary,
          ),
        ],
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final int singlePrice;
  final int count;
  final int discountPercent;
  final int totalPrice;
  final int originalPrice;

  const _TotalCard({
    required this.singlePrice,
    required this.count,
    required this.discountPercent,
    required this.totalPrice,
    required this.originalPrice,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppStyles.adaptivePrimaryBg(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Стоимость одной мойки',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
              ),
              Text(
                '$singlePrice ₽',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.adaptiveTextPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Количество',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  color: AppStyles.adaptiveTextPrimary(context),
                ),
              ),
            ],
          ),
          if (discountPercent > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Скидка',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                ),
                Text(
                  '-$discountPercent%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Без скидки',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppStyles.adaptiveTextSecondary(context),
                  ),
                ),
                Text(
                  '$originalPrice ₽',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppStyles.adaptiveTextMuted(context),
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Итого',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.adaptiveTextPrimary(context),
                ),
              ),
              Text(
                '$totalPrice ₽',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
