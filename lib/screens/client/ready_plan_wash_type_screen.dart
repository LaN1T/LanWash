import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/subscription_plan.dart';
import '../../models/wash_type.dart';
import '../../services/api_service.dart';
import 'subscription_checkout_screen.dart';

class ReadyPlanWashTypeScreen extends StatefulWidget {
  final SubscriptionPlan plan;

  const ReadyPlanWashTypeScreen({super.key, required this.plan});

  @override
  State<ReadyPlanWashTypeScreen> createState() =>
      _ReadyPlanWashTypeScreenState();
}

class _ReadyPlanWashTypeScreenState extends State<ReadyPlanWashTypeScreen> {
  List<WashType> _washTypes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<ApiService>().getWashTypes();
    if (mounted) {
      setState(() {
        _washTypes = list..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        _loading = false;
      });
    }
  }

  int _priceFor(WashType wt) {
    if (widget.plan.isUnlimited) {
      return widget.plan.washTypePrices?[wt.id] ?? wt.basePrice;
    }
    final count = widget.plan.washCount ?? 1;
    return wt.basePrice * count * (100 - widget.plan.discountPercent) ~/ 100;
  }

  int _originalPriceFor(WashType wt) {
    if (widget.plan.isUnlimited) {
      return widget.plan.washTypePrices?[wt.id] ?? wt.basePrice;
    }
    final count = widget.plan.washCount ?? 1;
    return wt.basePrice * count;
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
        title: const Text('Тип мойки',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppStyles.primary))
          : ListView.builder(
              padding: AppStyles.pagePadding,
              itemCount: _washTypes.length,
              itemBuilder: (ctx, i) {
                final wt = _washTypes[i];
                final price = _priceFor(wt);
                final original = _originalPriceFor(wt);
                return _WashTypeCard(
                  washType: wt,
                  price: price,
                  originalPrice: original,
                  discountPercent: widget.plan.discountPercent,
                  isUnlimited: widget.plan.isUnlimited,
                  onTap: () => Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => SubscriptionCheckoutScreen.ready(
                                name: widget.plan.name,
                                planId: widget.plan.id,
                                washTypeId: wt.id,
                                washTypeName: wt.name,
                                price: price,
                                originalPrice: original,
                              ))),
                );
              },
            ),
    );
  }
}

class _WashTypeCard extends StatelessWidget {
  final WashType washType;
  final int price;
  final int originalPrice;
  final int discountPercent;
  final bool isUnlimited;
  final VoidCallback onTap;

  const _WashTypeCard({
    required this.washType,
    required this.price,
    required this.originalPrice,
    required this.discountPercent,
    required this.isUnlimited,
    required this.onTap,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        washType.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppStyles.adaptiveTextPrimary(context),
                        ),
                      ),
                      if (washType.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            washType.description,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppStyles.adaptiveTextSecondary(context),
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (!isUnlimited && discountPercent > 0)
                        Row(
                          children: [
                            Text(
                              '$originalPrice ₽',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppStyles.adaptiveTextMuted(context),
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    AppStyles.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '-$discountPercent%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppStyles.success,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$price ₽',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppStyles.primary,
                      ),
                    ),
                    if (!isUnlimited)
                      Text(
                        '${washType.basePrice} ₽ / мойка',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppStyles.adaptiveTextSecondary(context),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right,
                    color: AppStyles.adaptiveTextMuted(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
