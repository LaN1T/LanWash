import 'package:flutter/material.dart';
import '../../app_styles.dart';
import '../../models/consumable_forecast.dart';
import '../../services/api_service.dart';
import 'package:lanwash/core/service_locator.dart';

class InventoryForecastScreen extends StatefulWidget {
  const InventoryForecastScreen({super.key});

  @override
  State<InventoryForecastScreen> createState() =>
      _InventoryForecastScreenState();
}

class _InventoryForecastScreenState extends State<InventoryForecastScreen> {
  InventoryForecastResponse? _forecast;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await sl<ApiService>().getInventoryForecast();
    if (mounted) {
      setState(() {
        _loading = false;
        if (result == null) {
          _error = 'Не удалось загрузить прогноз';
        } else {
          _forecast = result;
        }
      });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'critical':
        return AppStyles.danger;
      case 'warning':
        return AppStyles.warning;
      case 'ok':
        return AppStyles.success;
      default:
        return AppStyles.adaptiveTextSecondary(context);
    }
  }

  String _formatNumber(double value) {
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppStyles.isDark(context);
    final criticalCount = _forecast?.criticalItems.length ?? 0;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Прогноз расходников',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
        ),
      ),
      body: RefreshIndicator(
        color: AppStyles.primary,
        onRefresh: _load,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppStyles.primary),
              )
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          style: const TextStyle(color: AppStyles.danger),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppStyles.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : _forecast == null || _forecast!.items.isEmpty
                    ? const Center(child: Text('Нет данных'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                        itemCount: _forecast!.items.length +
                            (criticalCount > 0 ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (criticalCount > 0 && index == 0) {
                            return _buildCriticalBanner(criticalCount);
                          }
                          final item = _forecast!
                              .items[index - (criticalCount > 0 ? 1 : 0)];
                          return _buildItemCard(item);
                        },
                      ),
      ),
    );
  }

  Widget _buildCriticalBanner(int count) {
    final label = _pluralize(count, 'расходник', 'расходника', 'расходников');
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppStyles.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppStyles.danger.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppStyles.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '⚠️ $count $label требует срочной закупки',
              style: const TextStyle(
                color: AppStyles.danger,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ConsumableForecastItem item) {
    final statusColor = _statusColor(item.status);
    final daysUntilLow = item.daysUntilLow;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppStyles.adaptiveCard(context),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: item.isCritical
              ? AppStyles.danger.withValues(alpha: 0.35)
              : AppStyles.adaptiveBorder(context),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: statusColor.withValues(alpha: 0.12),
              child: Icon(
                Icons.inventory_2_outlined,
                color: statusColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppStyles.adaptiveTextPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Остаток: ${_formatNumber(item.currentStock)} ${item.unit}\n'
                    'Расход/день: ${_formatNumber(item.avgDailyUsage)} ${item.unit}\n'
                    'До минимума: ${daysUntilLow != null ? '${_formatNumber(daysUntilLow)} дн.' : '—'}',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppStyles.adaptiveTextSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Заказать:',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppStyles.adaptiveTextMuted(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatNumber(item.recommendedOrderAmount)} ${item.unit}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppStyles.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _pluralize(int count, String one, String few, String many) {
    final n = count % 100;
    if (n >= 11 && n <= 19) return many;
    switch (count % 10) {
      case 1:
        return one;
      case 2:
      case 3:
      case 4:
        return few;
      default:
        return many;
    }
  }
}
