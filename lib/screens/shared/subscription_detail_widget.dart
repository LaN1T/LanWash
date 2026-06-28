import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/subscription.dart';
import '../../providers/catalog_provider.dart';
import '../../models/service.dart';

class SubscriptionDetailWidget extends StatelessWidget {
  final Subscription subscription;

  const SubscriptionDetailWidget({
    super.key,
    required this.subscription,
  });

  bool get _isActive => subscription.isActive;

  bool get _isUnlimited =>
      subscription.type == 'monthly' || subscription.totalWashes >= 999999;

  String _remainingLabel() {
    if (_isUnlimited) {
      if (subscription.validUntil != null && subscription.validUntil!.isNotEmpty) {
        return 'Действует до ${_formatDate(subscription.validUntil!)}';
      }
      return 'Безлимитный абонемент';
    }
    final remaining = subscription.remaining;
    final word = remaining == 1
        ? 'мойка'
        : remaining < 5
            ? 'мойки'
            : 'моек';
    return 'Осталось $remaining $word';
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('d MMMM yyyy', 'ru').format(dt);
    } catch (_) {
      return iso;
    }
  }

  List<String> _selectedExtraIds() {
    final raw = subscription.selectedExtras;
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.watch<CatalogProvider>();
    final washType = catalogProvider.washTypeById(subscription.washTypeId);
    final extraIds = _selectedExtraIds();
    final createdAt = _formatDate(subscription.createdAt);

    return Container(
      decoration: BoxDecoration(
        color: AppStyles.adaptiveCard(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppStyles.adaptiveBorder(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Text('Детали абонемента', style: AppStyles.headingMedium),
          const SizedBox(height: 16),
          _StatusBanner(isActive: _isActive),
          const SizedBox(height: 16),
          _Row(Icons.label_outline, 'Название', subscription.name),
          _Row(
            Icons.category_outlined,
            'Тип',
            subscription.type == 'monthly' ? 'Безлимитка' : 'Пакет моек',
          ),
          _Row(Icons.local_car_wash_outlined, 'Тип мойки',
              washType?.name ?? subscription.washTypeId),
          _Row(Icons.card_membership_outlined, 'Остаток', _remainingLabel()),
          if (!_isUnlimited)
            _Row(Icons.format_list_numbered, 'Использовано',
                '${subscription.usedWashes} / ${subscription.totalWashes}'),
          _Row(Icons.payments_outlined, 'Цена', '${subscription.price} ₽'),
          if (subscription.originalPrice > subscription.price)
            _Row(Icons.savings_outlined, 'Экономия',
                '${subscription.originalPrice - subscription.price} ₽'),
          _Row(Icons.calendar_today_outlined, 'Куплен', createdAt),
          if (extraIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showExtras(context, catalogProvider.services, extraIds),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppStyles.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppStyles.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.list_alt,
                        size: 20, color: AppStyles.primary),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            'Доп. услуги абонемента (${extraIds.length})',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppStyles.primary))),
                    const Icon(Icons.chevron_right, color: AppStyles.primary),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showExtras(BuildContext context, List<Service> services, List<String> ids) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyles.adaptiveCard(context),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Доп. услуги абонемента',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: ids.length,
                itemBuilder: (context, index) {
                  final id = ids[index];
                  final service = services.firstWhere(
                    (s) => s.id == id,
                    orElse: () => Service(
                      id: id,
                      name: 'Услуга недоступна',
                      description: '',
                      price: 0,
                      durationMinutes: 0,
                      category: '',
                    ),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: AppStyles.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text(service.name,
                                style: const TextStyle(fontSize: 16))),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyles.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final bool isActive;
  const _StatusBanner({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppStyles.success : AppStyles.textMuted;
    final label = isActive ? 'Активен' : 'Неактивен';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Icon(isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: color, size: 24),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Статус',
              style: TextStyle(
                  fontSize: 12,
                  color: AppStyles.adaptiveTextSecondary(context))),
          Text(label,
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ]),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Row(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, size: 18, color: AppStyles.adaptiveTextSecondary(context)),
          const SizedBox(width: 12),
          Text(label,
              style: TextStyle(
                  color: AppStyles.adaptiveTextSecondary(context),
                  fontSize: 14)),
          const Spacer(),
          Text(value,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        ]),
      );
}
