import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/tip.dart';
import '../../services/api_service.dart';

class WasherTipsScreen extends StatefulWidget {
  const WasherTipsScreen({super.key});

  @override
  State<WasherTipsScreen> createState() => _WasherTipsScreenState();
}

class _WasherTipsScreenState extends State<WasherTipsScreen> {
  List<Tip> _tips = [];
  bool _tipsLoading = false;
  TipStats? _tipStats;

  @override
  void initState() {
    super.initState();
    _loadTips();
  }

  Future<void> _loadTips() async {
    setState(() => _tipsLoading = true);
    final api = context.read<ApiService>();
    final tips = await api.getMyTips();
    final stats = await api.getTipStats();
    if (mounted) {
      setState(() {
        _tips = tips;
        _tipStats = stats;
        _tipsLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чаевые'),
      ),
      body: _tipsLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppStyles.primary))
          : RefreshIndicator(
              color: AppStyles.primary,
              onRefresh: _loadTips,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_tipStats != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppStyles.adaptiveCard(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppStyles.adaptiveBorder(context)),
                      ),
                      child: Row(
                        children: [
                          _StatItem('Всего', _tipStats!.totalTips.toString()),
                          const VerticalDivider(),
                          _StatItem(
                              'Получено', '${_tipStats!.totalAmount} ₽'),
                          const VerticalDivider(),
                          _StatItem('Ожидает',
                              '${_tipStats!.pendingAmount} ₽'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_tips.isEmpty)
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 40),
                          Icon(Icons.volunteer_activism,
                              size: 56,
                              color: AppStyles.adaptiveTextSecondary(context)
                                  .withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('Пока нет чаевых',
                              style: AppStyles.headingMedium.copyWith(
                                  color: AppStyles.adaptiveTextSecondary(
                                      context))),
                        ],
                      ),
                    )
                  else
                    ..._tips.map((t) => _TipCard(
                          tip: t,
                          onRefresh: _loadTips,
                        )),
                ],
              ),
            ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppStyles.primary)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppStyles.adaptiveTextSecondary(context))),
        ],
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final Tip tip;
  final VoidCallback onRefresh;
  const _TipCard({required this.tip, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final isPending = tip.status == 'pending';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: AppStyles.adaptiveCard(context),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: AppStyles.adaptiveBorder(context))),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: isPending
                        ? AppStyles.warning.withValues(alpha: 0.1)
                        : AppStyles.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: Text(tip.statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            isPending ? AppStyles.warning : AppStyles.success)),
              ),
              const Spacer(),
              Text('${tip.amount} ₽',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppStyles.primary)),
            ]),
            const SizedBox(height: 10),
            Text('Способ: ${tip.methodLabel}',
                style: TextStyle(
                    fontSize: 13,
                    color: AppStyles.adaptiveTextSecondary(context))),
            const SizedBox(height: 4),
            Text('Запись: ${tip.appointmentId}',
                style: TextStyle(
                    fontSize: 12,
                    color: AppStyles.adaptiveTextSecondary(context))),
            if (isPending && tip.method != 'sbp') ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final scaffold = ScaffoldMessenger.of(context);
                    final ok =
                        await context.read<ApiService>().markTipPaid(tip.id);
                    if (ok) {
                      onRefresh();
                    } else {
                      scaffold.showSnackBar(
                        const SnackBar(
                            content: Text('Не удалось отметить'),
                            backgroundColor: AppStyles.danger),
                      );
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Отметить получено'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppStyles.success,
                    side: const BorderSide(color: AppStyles.success),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
