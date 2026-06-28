import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/consumable.dart';
import '../../models/consumable_history_item.dart';
import '../../providers/consumable_provider.dart';

class ConsumableHistoryScreen extends StatefulWidget {
  final Consumable consumable;

  const ConsumableHistoryScreen({
    super.key,
    required this.consumable,
  });

  @override
  State<ConsumableHistoryScreen> createState() =>
      _ConsumableHistoryScreenState();
}

class _ConsumableHistoryScreenState extends State<ConsumableHistoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loadingConsumption = true;
  bool _loadingRefill = true;
  List<ConsumableHistoryItem> _consumption = [];
  List<ConsumableHistoryItem> _refills = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<ConsumableProvider>();
    final results = await Future.wait([
      provider.getHistory(widget.consumable.id, 'consumption'),
      provider.getHistory(widget.consumable.id, 'refill'),
    ]);
    if (mounted) {
      setState(() {
        _consumption = results[0];
        _refills = results[1];
        _loadingConsumption = false;
        _loadingRefill = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.consumable;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          c.name,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppStyles.primary,
          unselectedLabelColor: AppStyles.adaptiveTextSecondary(context),
          indicatorColor: AppStyles.primary,
          tabs: const [
            Tab(text: 'Списания'),
            Tab(text: 'Пополнения'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _HistoryList(
            items: _consumption,
            loading: _loadingConsumption,
            unit: c.unit,
            emptyText: 'Списаний пока нет',
          ),
          _HistoryList(
            items: _refills,
            loading: _loadingRefill,
            unit: c.unit,
            isRefill: true,
            emptyText: 'Пополнений пока нет',
          ),
        ],
      ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<ConsumableHistoryItem> items;
  final bool loading;
  final String unit;
  final String emptyText;
  final bool isRefill;

  const _HistoryList({
    required this.items,
    required this.loading,
    required this.unit,
    required this.emptyText,
    this.isRefill = false,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppStyles.primary),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyText,
          style: TextStyle(
            color: AppStyles.adaptiveTextSecondary(context),
            fontSize: 15,
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final color = isRefill ? AppStyles.success : AppStyles.danger;
        final sign = isRefill ? '+' : '−';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppStyles.adaptiveCard(context),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppStyles.adaptiveBorder(context)),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                isRefill ? Icons.add : Icons.remove,
                color: color,
                size: 18,
              ),
            ),
            title: Text(
              '$sign${_formatQuantity(item.quantity)} $unit',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppStyles.adaptiveTextPrimary(context),
              ),
            ),
            subtitle: Text(
              dateFormat.format(item.timestamp.toLocal()),
              style: TextStyle(
                fontSize: 13,
                color: AppStyles.adaptiveTextSecondary(context),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatQuantity(double value) {
    return value.toStringAsFixed(value % 1 == 0 ? 0 : 1);
  }
}
