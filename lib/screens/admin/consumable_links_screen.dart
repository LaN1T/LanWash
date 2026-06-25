import 'package:flutter/material.dart';
import 'package:lanwash/app_styles.dart';
import 'package:lanwash/core/service_locator.dart';
import 'package:lanwash/models/consumable.dart';
import 'package:lanwash/models/service.dart';
import 'package:lanwash/models/wash_type.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:lanwash/widgets/admin/report_dropdown_field.dart';

class _Link {
  final String consumableId;
  final String name;
  final String unit;
  final double quantity;

  _Link({
    required this.consumableId,
    required this.name,
    required this.unit,
    required this.quantity,
  });
}

class ConsumableLinksScreen extends StatefulWidget {
  const ConsumableLinksScreen({super.key});

  @override
  State<ConsumableLinksScreen> createState() => _ConsumableLinksScreenState();
}

class _ConsumableLinksScreenState extends State<ConsumableLinksScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;
  String? _error;

  List<WashType> _washTypes = [];
  List<Service> _services = [];
  List<Consumable> _consumables = [];
  Map<String, List<_Link>> _washTypeLinks = {};
  Map<String, List<_Link>> _serviceLinks = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = sl<ApiService>();
      final washTypes = await api.getWashTypes();
      final services = await api.getServices();
      final consumables = await api.getConsumables();
      final wtLinks = await api.getWashTypeConsumableLinks();
      final svcLinks = await api.getServiceConsumableLinks();

      final consumableMap = {
        for (final c in consumables) c.id: c,
      };

      if (!mounted) return;
      setState(() {
        _washTypes = washTypes;
        _services = services;
        _consumables = consumables;
        _washTypeLinks = _groupLinks(wtLinks, consumableMap, 'washTypeId');
        _serviceLinks = _groupLinks(svcLinks, consumableMap, 'serviceId');
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _loading = false;
      });
    }
  }

  Map<String, List<_Link>> _groupLinks(
    List<Map<String, dynamic>> links,
    Map<String, Consumable> consumableMap,
    String targetIdKey,
  ) {
    final result = <String, List<_Link>>{};
    for (final link in links) {
      final targetId = link[targetIdKey]?.toString() ?? '';
      final consumableId = link['consumableId']?.toString() ?? '';
      final quantity =
          (link['quantity_per_service'] as num?)?.toDouble() ?? 0.0;
      final consumable = consumableMap[consumableId];
      if (consumable == null) continue;
      result.putIfAbsent(targetId, () => []).add(_Link(
            consumableId: consumableId,
            name: consumable.name,
            unit: consumable.unit,
            quantity: quantity,
          ));
    }
    return result;
  }

  Future<void> _addLink(
    String targetId,
    String consumableId,
    double quantity,
    bool isWashType,
  ) async {
    final api = sl<ApiService>();
    if (isWashType) {
      await api.linkConsumableToWashType(targetId, consumableId, quantity);
    } else {
      await api.linkConsumableToService(targetId, consumableId, quantity);
    }
    await _load();
  }

  Future<void> _removeLink(
    String targetId,
    String consumableId,
    bool isWashType,
  ) async {
    final api = sl<ApiService>();
    if (isWashType) {
      await api.unlinkConsumableFromWashType(targetId, consumableId);
    } else {
      await api.unlinkConsumableFromService(targetId, consumableId);
    }
    await _load();
  }

  void _showAddLinkSheet(String targetId, String targetName, bool isWashType) {
    String? selectedConsumableId;
    final quantityController = TextEditingController(text: '0');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Привязать расходник к "$targetName"',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.adaptiveTextPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ReportDropdownField<String>(
                    label: 'Расходник',
                    value: selectedConsumableId,
                    items: _consumables
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.name} (${c.unit})'),
                            ))
                        .toList(),
                    onChanged: (id) => setLocalState(() {
                      selectedConsumableId = id;
                    }),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: AppStyles.inputDecorationFor(ctx, 'Количество'),
                    style: TextStyle(
                      color: AppStyles.adaptiveTextPrimary(ctx),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: selectedConsumableId == null
                          ? null
                          : () async {
                              final quantity =
                                  double.tryParse(quantityController.text) ?? 0;
                              if (quantity <= 0) return;
                              Navigator.pop(ctx);
                              await _addLink(
                                targetId,
                                selectedConsumableId!,
                                quantity,
                                isWashType,
                              );
                            },
                      child: const Text('Сохранить'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildWashTypeList() {
    return _buildTypedList<WashType>(
      _washTypes,
      _washTypeLinks,
      true,
      (wt) => wt.name,
    );
  }

  Widget _buildServiceList() {
    return _buildTypedList<Service>(
      _services,
      _serviceLinks,
      false,
      (s) => s.name,
    );
  }

  Widget _buildTypedList<T>(
    List<T> targets,
    Map<String, List<_Link>> links,
    bool isWashType,
    String Function(T) nameOf,
  ) {
    if (targets.isEmpty) {
      return const Center(child: Text('Нет данных'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: targets.length,
      itemBuilder: (ctx, i) {
        final target = targets[i];
        final targetId = (target as dynamic).id as String;
        final targetName = nameOf(target);
        final targetLinks = links[targetId] ?? [];
        return _AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      targetName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppStyles.adaptiveTextPrimary(ctx),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: AppStyles.primary,
                    onPressed: () => _showAddLinkSheet(
                      targetId,
                      targetName,
                      isWashType,
                    ),
                  ),
                ],
              ),
              if (targetLinks.isEmpty)
                Text(
                  'Нет привязанных расходников',
                  style: TextStyle(
                    color: AppStyles.adaptiveTextMuted(ctx),
                    fontSize: 13,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: targetLinks.map((link) {
                    return Chip(
                      label: Text(
                        '${link.name}: ${link.quantity} ${link.unit}',
                        style: TextStyle(
                          color: AppStyles.adaptiveTextPrimary(ctx),
                          fontSize: 12,
                        ),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => _removeLink(
                        targetId,
                        link.consumableId,
                        isWashType,
                      ),
                      backgroundColor: AppStyles.adaptiveCard(ctx),
                      side: BorderSide(color: AppStyles.adaptiveBorder(ctx)),
                    );
                  }).toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Нормы расхода',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: AppStyles.danger, fontSize: 16)))
              : Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: AppStyles.primary,
                      unselectedLabelColor:
                          AppStyles.adaptiveTextSecondary(context),
                      indicatorColor: AppStyles.primary,
                      tabs: const [
                        Tab(text: 'Типы моек'),
                        Tab(text: 'Услуги'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildWashTypeList(),
                          _buildServiceList(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _AdminCard extends StatelessWidget {
  final Widget child;
  const _AdminCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppStyles.adaptiveBorder(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
