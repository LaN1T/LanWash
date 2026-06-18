import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/consumable.dart';
import '../../services/api_service.dart';

class ConsumablesStockScreen extends StatefulWidget {
  const ConsumablesStockScreen({super.key});

  @override
  State<ConsumablesStockScreen> createState() => _ConsumablesStockScreenState();
}

class _ConsumablesStockScreenState extends State<ConsumablesStockScreen> {
  bool _loading = true;
  List<Consumable> _consumables = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = context.read<ApiService>();
    final list = await api.getConsumables();
    if (mounted) {
      setState(() {
        _consumables = list;
        _loading = false;
      });
    }
  }

  Future<void> _refill(Consumable c) async {
    final ctrl = TextEditingController();
    final api = context.read<ApiService>();
    final amount = await showDialog<double>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Пополнить ${c.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Количество (${c.unit})',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(context, val);
            },
            child: const Text('Пополнить'),
          ),
        ],
      ),
    );
    if (amount == null || amount <= 0) return;

    final updated = await api.refillConsumable(c.id, amount);
    if (updated != null && mounted) {
      _showSnack('${updated.name} пополнено на $amount ${updated.unit}');
      _load();
    }
  }

  void _showSnack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? AppStyles.success),
    );
  }

  void _openDetail(Consumable c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ConsumableDetailSheet(consumable: c),
    );
  }

  Future<void> _downloadReport() async {
    final api = context.read<ApiService>();
    final bytes = await api.downloadConsumablesReport();
    if (bytes == null) {
      _showSnack('Не удалось скачать отчёт', color: AppStyles.danger);
      return;
    }
    final name =
        'consumables_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    await FileSaver.instance.saveFile(
      name: name.replaceAll('.xlsx', ''),
      bytes: bytes,
      mimeType: MimeType.microsoftExcel,
    );
    _showSnack('Отчёт сохранён');
  }

  Future<void> _downloadTemplate() async {
    final api = context.read<ApiService>();
    final bytes = await api.downloadImportTemplate();
    if (bytes == null) {
      _showSnack('Не удалось скачать шаблон', color: AppStyles.danger);
      return;
    }
    await FileSaver.instance.saveFile(
      name: 'consumables_import_template',
      bytes: bytes,
      mimeType: MimeType.microsoftExcel,
    );
    _showSnack('Шаблон сохранён');
  }

  Future<void> _uploadRefills() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.bytes == null) {
      return;
    }
    if (!mounted) return;

    final bytes = result.files.first.bytes!;
    final fileName = result.files.first.name;

    // Показываем подтверждение
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Импорт пополнений'),
        content: Text('Загрузить файл "$fileName"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Загрузить')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final api = context.read<ApiService>();
    final response = await api.uploadRefillsFromExcel(bytes);
    if (!mounted) return;
    if (response == null) {
      _showSnack('Ошибка загрузки', color: AppStyles.danger);
      return;
    }

    final succeeded = response['succeeded'] ?? 0;
    final failed = response['failed'] ?? 0;
    final errors = (response['errors'] as List?)?.cast<String>() ?? [];

    if (failed == 0) {
      _showSnack('Успешно импортировано: $succeeded');
    } else {
      _showSnack('Успешно: $succeeded, ошибок: $failed',
          color: AppStyles.warning);
      if (errors.isNotEmpty && mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Ошибки импорта'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: errors.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• ${errors[i]}',
                      style: const TextStyle(fontSize: 13)),
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Закрыть'))
            ],
          ),
        );
      }
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _consumables.where((c) => c.isLowStock).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Управление запасами'),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: AppStyles.adaptiveBorder(context)),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _downloadReport();
                  break;
                case 'import':
                  _uploadRefills();
                  break;
                case 'template':
                  _downloadTemplate();
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'export', child: Text('Скачать отчёт')),
              const PopupMenuItem(
                  value: 'import', child: Text('Загрузить пополнения')),
              const PopupMenuItem(
                  value: 'template', child: Text('Скачать шаблон')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  if (alerts.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppStyles.danger.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppStyles.danger.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded,
                                  color: AppStyles.danger, size: 18),
                              const SizedBox(width: 6),
                              Text(
                                'Требуется пополнение (${alerts.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppStyles.danger,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: alerts
                                .map((c) => Chip(
                                      label: Text(c.name,
                                          style: const TextStyle(fontSize: 12)),
                                      backgroundColor: AppStyles.danger
                                          .withValues(alpha: 0.1),
                                      side: BorderSide.none,
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  ..._consumables.map((c) => _buildCard(c)),
                ],
              ),
            ),
    );
  }

  Widget _buildCard(Consumable c) {
    final isLow = c.isLowStock;
    final progress = c.minStock > 0
        ? (c.currentStock / (c.minStock * 3)).clamp(0.0, 1.0)
        : 1.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppStyles.adaptiveCard(context),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLow
              ? AppStyles.danger.withValues(alpha: 0.3)
              : AppStyles.adaptiveBorder(context),
        ),
      ),
      child: InkWell(
        onTap: () => _openDetail(c),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isLow)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppStyles.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Низкий запас',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppStyles.danger,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: AppStyles.adaptiveBorder(context),
                valueColor: AlwaysStoppedAnimation(
                  isLow ? AppStyles.danger : AppStyles.primary,
                ),
                borderRadius: BorderRadius.circular(4),
                minHeight: 6,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${c.currentStock.toStringAsFixed(c.currentStock % 1 == 0 ? 0 : 1)} ${c.unit}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isLow
                          ? AppStyles.danger
                          : AppStyles.adaptiveTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'мин. ${c.minStock.toStringAsFixed(c.minStock % 1 == 0 ? 0 : 1)} ${c.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppStyles.adaptiveTextSecondary(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _refill(c),
                    icon: const Icon(Icons.add, size: 16),
                    label:
                        const Text('Пополнить', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppStyles.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsumableDetailSheet extends StatefulWidget {
  final Consumable consumable;

  const _ConsumableDetailSheet({required this.consumable});

  @override
  State<_ConsumableDetailSheet> createState() => _ConsumableDetailSheetState();
}

class _ConsumableDetailSheetState extends State<_ConsumableDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingHistory = true;
  bool _loadingForecast = true;
  List<ConsumableRefillLog> _history = [];
  ConsumableForecast? _forecast;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final api = context.read<ApiService>();
    final history = await api.getRefillHistory(widget.consumable.id);
    final forecast = await api.getConsumableForecast(widget.consumable.id);
    if (mounted) {
      setState(() {
        _history = history;
        _forecast = forecast;
        _loadingHistory = false;
        _loadingForecast = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consumable;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              color: AppStyles.adaptiveCard(context),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppStyles.adaptiveBorder(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    c.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  labelColor: AppStyles.primary,
                  unselectedLabelColor:
                      AppStyles.adaptiveTextSecondary(context),
                  indicatorColor: AppStyles.primary,
                  tabs: const [
                    Tab(text: 'Обзор'),
                    Tab(text: 'История'),
                    Tab(text: 'Прогноз'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(c),
                      _buildHistoryTab(),
                      _buildForecastTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab(Consumable c) {
    final isLow = c.isLowStock;
    final progress = c.minStock > 0
        ? (c.currentStock / (c.minStock * 3)).clamp(0.0, 1.0)
        : 1.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiCard(
              'Текущий запас',
              '${c.currentStock.toStringAsFixed(c.currentStock % 1 == 0 ? 0 : 1)} ${c.unit}',
              isLow ? AppStyles.danger : AppStyles.primary),
          const SizedBox(height: 10),
          _kpiCard(
              'Минимальный запас',
              '${c.minStock.toStringAsFixed(c.minStock % 1 == 0 ? 0 : 1)} ${c.unit}',
              AppStyles.adaptiveTextSecondary(context)),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: AppStyles.adaptiveBorder(context),
            valueColor: AlwaysStoppedAnimation(
              isLow ? AppStyles.danger : AppStyles.primary,
            ),
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            isLow ? 'Запас ниже нормы' : 'Запас в норме',
            style: TextStyle(
              color: isLow ? AppStyles.danger : AppStyles.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 20, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_history.isEmpty) {
      return const Center(child: Text('История пополнений пуста'));
    }
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _history.length,
      itemBuilder: (_, i) {
        final log = _history[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppStyles.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.add, color: AppStyles.primary, size: 18),
          ),
          title: Text(
              '+${log.amount.toStringAsFixed(log.amount % 1 == 0 ? 0 : 1)} ${widget.consumable.unit}'),
          subtitle: Text(
              '${log.refilledBy}  •  ${fmt.format(DateTime.parse(log.timestamp))}'),
          trailing: Text(
            '${log.oldStock.toStringAsFixed(1)} → ${log.newStock.toStringAsFixed(1)}',
            style: TextStyle(
                fontSize: 12, color: AppStyles.adaptiveTextSecondary(context)),
          ),
        );
      },
    );
  }

  Widget _buildForecastTab() {
    if (_loadingForecast) {
      return const Center(child: CircularProgressIndicator());
    }
    final f = _forecast;
    if (f == null) {
      return const Center(child: Text('Не удалось загрузить прогноз'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _kpiCard(
              'Средний расход в день',
              '${f.avgDailyUsage.toStringAsFixed(f.avgDailyUsage % 1 == 0 ? 0 : 1)} ${f.unit}',
              AppStyles.primary),
          const SizedBox(height: 10),
          if (f.daysLeft != null)
            _kpiCard(
                'Хватит на',
                '${f.daysLeft!.toStringAsFixed(f.daysLeft! % 1 == 0 ? 0 : 1)} дн.',
                f.daysLeft! < 7 ? AppStyles.danger : AppStyles.success)
          else
            _kpiCard('Хватит на', 'Недостаточно данных',
                AppStyles.adaptiveTextSecondary(context)),
          const SizedBox(height: 10),
          _kpiCard(
              'Рекомендуемая закупка',
              '${f.suggestedPurchase.toStringAsFixed(f.suggestedPurchase % 1 == 0 ? 0 : 1)} ${f.unit}',
              AppStyles.warning),
          const SizedBox(height: 10),
          Text(
            'Целевой запас: ${f.targetStock.toStringAsFixed(f.targetStock % 1 == 0 ? 0 : 1)} ${f.unit}',
            style: TextStyle(
                color: AppStyles.adaptiveTextSecondary(context), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
