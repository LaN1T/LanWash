import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../app_styles.dart';
import '../../models/subscription.dart';
import '../../providers/catalog_provider.dart';
import '../../services/api_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  List<Subscription> _active = [];
  List<Subscription> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<ApiService>().getMySubscriptions();
    if (mounted) {
      setState(() {
        _active = list.where((s) => s.isActive).toList();
        _history = list.where((s) => !s.isActive).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _loading = false;
      });
    }
  }

  String _washTypeName(String washTypeId) {
    final wt = context.read<CatalogProvider>().washTypeById(washTypeId);
    return wt?.name ?? washTypeId;
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
        title: const Text('Мои абонементы',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppStyles.primary,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppStyles.primary))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_active.isNotEmpty) ...[
                    _sectionLabel('Активные'),
                    const SizedBox(height: 12),
                    ..._active.map((s) => _buildSubscriptionCard(s, true)),
                    const SizedBox(height: 24),
                  ],
                  if (_history.isNotEmpty) ...[
                    _sectionLabel('История'),
                    const SizedBox(height: 12),
                    ..._history.take(5).map((s) => _buildSubscriptionCard(s, false)),
                  ],
                  if (_active.isEmpty && _history.isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 80),
                          Icon(Icons.card_membership_outlined,
                              size: 56, color: AppStyles.adaptiveTextMuted(context)),
                          const SizedBox(height: 16),
                          Text(
                            'У вас пока нет абонементов',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: AppStyles.adaptiveTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(
          color: AppStyles.adaptiveTextSecondary(context),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1));

  Widget _buildSubscriptionCard(Subscription s, bool isActive) {
    final progress = s.progress.clamp(0.0, 1.0);
    final remaining = s.remaining;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppStyles.primary.withValues(alpha: 0.12)
                      : AppStyles.adaptiveBgMuted(context),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.type == 'monthly' ? 'Абонемент' : 'Пакет',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isActive ? AppStyles.primary : AppStyles.adaptiveTextMuted(context),
                  ),
                ),
              ),
              const Spacer(),
              if (!isActive)
                Text(
                  s.usedWashes >= s.totalWashes ? 'Исчерпан' : 'Истёк',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.danger,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            s.name,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppStyles.adaptiveTextPrimary(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _washTypeName(s.washTypeId),
            style: TextStyle(
              fontSize: 13,
              color: AppStyles.adaptiveTextSecondary(context),
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppStyles.adaptiveBgMuted(context),
              color: isActive ? AppStyles.primary : AppStyles.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.type == 'monthly'
                    ? (s.validUntil != null
                        ? 'Действует до: ${_formatDate(s.validUntil!)}'
                        : 'Действует до: —')
                    : 'Осталось: $remaining ${remaining == 1 ? 'мойка' : remaining < 5 ? 'мойки' : 'моек'}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppStyles.adaptiveTextSecondary(context),
                ),
              ),
              Text(
                '${s.usedWashes} / ${s.totalWashes}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppStyles.adaptiveTextMuted(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('d MMMM yyyy', 'ru').format(dt);
    } catch (_) {
      return iso;
    }
  }
}
