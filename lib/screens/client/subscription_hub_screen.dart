import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/subscription.dart';
import '../../services/api_service.dart';
import 'subscription_screen.dart';
import 'subscription_type_choice_screen.dart';

class SubscriptionHubScreen extends StatefulWidget {
  const SubscriptionHubScreen({super.key});

  @override
  State<SubscriptionHubScreen> createState() => _SubscriptionHubScreenState();
}

class _SubscriptionHubScreenState extends State<SubscriptionHubScreen> {
  List<Subscription> _subscriptions = [];
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
        _subscriptions = list.where((s) => s.isActive).toList();
        _loading = false;
      });
    }
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
        title: const Text('Абонементы',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppStyles.primary,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppStyles.primary))
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const SubscriptionTypeChoiceScreen())),
                        icon: const Icon(Icons.add),
                        label: const Text('Купить абонемент'),
                        style: AppStyles.primaryButton,
                      ),
                    ),
                  ),
                  if (_subscriptions.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.card_membership_outlined,
                                size: 56,
                                color: AppStyles.adaptiveTextMuted(context)),
                            const SizedBox(height: 16),
                            Text(
                              'У вас пока нет активных абонементов',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: AppStyles.adaptiveTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _SubscriptionCard(
                            subscription: _subscriptions[i],
                            onTap: () => Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SubscriptionScreen())),
                          ),
                          childCount: _subscriptions.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onTap;

  const _SubscriptionCard({required this.subscription, required this.onTap});

  bool get _isUnlimited =>
      subscription.type == 'monthly' || subscription.totalWashes >= 999999;

  String _remainingLabel() {
    if (_isUnlimited) {
      if (subscription.validUntil != null) {
        return 'Действует до: ${_formatDate(subscription.validUntil!)}';
      }
      return 'Безлимитный абонемент';
    }
    final remaining = subscription.remaining;
    final washesWord = remaining == 1
        ? 'мойка'
        : remaining < 5
            ? 'мойки'
            : 'моек';
    return 'Осталось: $remaining $washesWord';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('d MMMM yyyy', 'ru').format(dt);
    } catch (_) {
      return iso;
    }
  }

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppStyles.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        subscription.type == 'monthly' ? 'Абонемент' : 'Пакет',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppStyles.primary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        color: AppStyles.adaptiveTextMuted(context)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  subscription.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _remainingLabel(),
                      style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                    ),
                    if (!_isUnlimited)
                      Text(
                        '${subscription.usedWashes} / ${subscription.totalWashes}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.adaptiveTextMuted(context),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
