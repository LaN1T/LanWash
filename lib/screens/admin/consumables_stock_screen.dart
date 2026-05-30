import 'package:flutter/material.dart';
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
    _load();
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppStyles.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _consumables.where((c) => c.isLowStock).toList();

    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        title: const Text('Управление запасами'),
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
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
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isLow
              ? AppStyles.danger.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
              backgroundColor: Colors.grey.shade200,
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
                    color: isLow ? AppStyles.danger : AppStyles.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  'мин. ${c.minStock.toStringAsFixed(c.minStock % 1 == 0 ? 0 : 1)} ${c.unit}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppStyles.textSecondary,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
