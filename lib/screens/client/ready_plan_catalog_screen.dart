import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/subscription_plan.dart';
import '../../services/api_service.dart';
import 'ready_plan_wash_type_screen.dart';

class ReadyPlanCatalogScreen extends StatefulWidget {
  const ReadyPlanCatalogScreen({super.key});

  @override
  State<ReadyPlanCatalogScreen> createState() => _ReadyPlanCatalogScreenState();
}

class _ReadyPlanCatalogScreenState extends State<ReadyPlanCatalogScreen> {
  List<SubscriptionPlan> _plans = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await context.read<ApiService>().getSubscriptionPlans();
    if (mounted) {
      setState(() {
        _plans = list.where((p) => p.isActive).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
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
        title: const Text('Готовые абонементы',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppStyles.primary,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppStyles.primary))
            : _plans.isEmpty
                ? Center(
                    child: Text(
                      'Пока нет доступных абонементов',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: AppStyles.pagePadding,
                    itemCount: _plans.length,
                    itemBuilder: (ctx, i) {
                      final plan = _plans[i];
                      return _PlanCard(
                        plan: plan,
                        onTap: () => Navigator.push(
                            ctx,
                            MaterialPageRoute(
                                builder: (_) =>
                                    ReadyPlanWashTypeScreen(plan: plan))),
                      );
                    },
                  ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final SubscriptionPlan plan;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.onTap});

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
                        plan.isPackage ? 'Пакет' : 'Безлимит',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppStyles.primary,
                        ),
                      ),
                    ),
                    if (plan.discountPercent > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppStyles.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '-${plan.discountPercent}%',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppStyles.success,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Icon(Icons.chevron_right,
                        color: AppStyles.adaptiveTextMuted(context)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  plan.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppStyles.adaptiveTextPrimary(context),
                  ),
                ),
                if (plan.description != null && plan.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      plan.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppStyles.adaptiveTextSecondary(context),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
