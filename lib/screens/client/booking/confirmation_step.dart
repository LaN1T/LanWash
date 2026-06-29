import 'package:flutter/material.dart';
import '../../../app_styles.dart';
import '../../../models/service.dart';
import '../../../models/subscription.dart';
import '../../../models/wash_type.dart';

class ConfirmationStep extends StatelessWidget {
  final String date, name, car, number;
  final WashType? washType;
  final List<String> extras;
  final List<Service> services;
  final int finalPrice, regularPrice;
  final bool hasDiscount;
  final String? promoName;
  final String totalDurationLabel;
  final List<Subscription> subscriptions;
  final int? selectedSubscriptionId;
  final String? selectedSubscriptionName;
  final ValueChanged<int?> onSubscriptionChanged;

  const ConfirmationStep(
      {super.key,
      required this.date,
      required this.washType,
      required this.extras,
      required this.services,
      required this.name,
      required this.car,
      required this.number,
      required this.finalPrice,
      required this.regularPrice,
      required this.hasDiscount,
      this.promoName,
      required this.totalDurationLabel,
      this.subscriptions = const [],
      this.selectedSubscriptionId,
      this.selectedSubscriptionName,
      required this.onSubscriptionChanged});

  String _serviceName(String id) {
    for (final s in services) {
      if (s.id == id) return s.name;
    }
    return id;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Подтверждение',
                style: AppStyles.headingMedium
                    .copyWith(color: AppStyles.adaptiveTextPrimary(context))),
            const SizedBox(height: 4),
            Text('Проверьте данные перед записью',
                style: AppStyles.bodyMedium
                    .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
            const SizedBox(height: 20),
            if (promoName != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppStyles.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.local_offer_rounded,
                      color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(promoName!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600))),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            _ConfirmCard(
                icon: Icons.event_rounded,
                label: 'Дата и время',
                value: date,
                highlight: true),
            const SizedBox(height: 10),
            Container(
              decoration: AppStyles.cardDecorationFor(context),
              child: Column(children: [
                _ConfirmRow(Icons.person_outline_rounded, 'Клиент', name),
                Container(height: 1, color: AppStyles.adaptiveBorder(context)),
                _ConfirmRow(Icons.directions_car_outlined, 'Автомобиль', car),
                Container(height: 1, color: AppStyles.adaptiveBorder(context)),
                _ConfirmRow(Icons.pin_outlined, 'Гос. номер', number),
              ]),
            ),
            const SizedBox(height: 10),
            Container(
              decoration: AppStyles.cardDecorationFor(context),
              child: Column(children: [
                _ConfirmRow(Icons.local_car_wash_rounded, 'Тип мойки',
                    washType?.name ?? '—'),
                Container(height: 1, color: AppStyles.adaptiveBorder(context)),
                _ConfirmRow(
                    Icons.access_time_rounded, 'Время', totalDurationLabel),
                if (extras.isNotEmpty) ...[
                  Container(
                      height: 1, color: AppStyles.adaptiveBorder(context)),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Icon(Icons.add_circle_outline_rounded,
                                size: 16,
                                color:
                                    AppStyles.adaptiveTextSecondary(context)),
                            const SizedBox(width: 10),
                            Text('Доп. услуги',
                                style: TextStyle(
                                    color: AppStyles.adaptiveTextSecondary(
                                        context),
                                    fontSize: 13)),
                          ]),
                          const SizedBox(height: 10),
                          Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: extras
                                  .map((id) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: AppStyles.adaptivePrimaryBg(
                                              context),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: AppStyles.primary
                                                  .withValues(alpha: 0.2)),
                                        ),
                                        child: Text(_serviceName(id),
                                            style: const TextStyle(
                                                color: AppStyles.primary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500)),
                                      ))
                                  .toList()),
                        ]),
                  ),
                ],
              ]),
            ),
            if (subscriptions.isNotEmpty) ...[
              const SizedBox(height: 14),
              _SubscriptionSelector(
                subscriptions: subscriptions,
                selectedId: selectedSubscriptionId,
                onChanged: onSubscriptionChanged,
              ),
            ],
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppStyles.adaptivePrimaryBg(context),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppStyles.primary.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                const Icon(Icons.payments_outlined,
                    color: AppStyles.primary, size: 22),
                const SizedBox(width: 12),
                Text('Итого',
                    style: TextStyle(
                        color: AppStyles.adaptiveTextPrimary(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                      selectedSubscriptionName != null
                          ? '0 ₽'
                          : '$finalPrice ₽',
                      style: const TextStyle(
                          color: AppStyles.primary,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                  if (selectedSubscriptionName != null)
                    Text(
                      'Оплачено абонементом «$selectedSubscriptionName»',
                      style: TextStyle(
                        color: AppStyles.adaptiveTextSecondary(context),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.right,
                    )
                  else if (hasDiscount)
                    Text('$regularPrice ₽',
                        style: TextStyle(
                            color: AppStyles.adaptiveTextSecondary(context),
                            fontSize: 14,
                            decoration: TextDecoration.lineThrough,
                            decorationColor:
                                AppStyles.adaptiveTextSecondary(context))),
                ]),
              ]),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppStyles.adaptiveInnerCard(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                Icon(Icons.info_outline,
                    color: AppStyles.adaptiveTextSecondary(context), size: 16),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                  'После подтверждения администратор свяжется с вами для уточнения деталей',
                  style: TextStyle(
                      color: AppStyles.adaptiveTextSecondary(context),
                      fontSize: 12),
                )),
              ]),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool highlight;
  const _ConfirmCard(
      {required this.icon,
      required this.label,
      required this.value,
      this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: AppStyles.cardDecorationFor(context),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppStyles.adaptivePrimaryBg(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppStyles.primary, size: 20),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: AppStyles.label
                    .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                  color: highlight
                      ? AppStyles.primary
                      : AppStyles.adaptiveTextPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                )),
          ]),
        ]),
      );
}

class _ConfirmRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _ConfirmRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppStyles.adaptiveInnerCard(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon,
                size: 16, color: AppStyles.adaptiveTextSecondary(context)),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 110,
            child: Text(label,
                style: AppStyles.bodyMedium
                    .copyWith(color: AppStyles.adaptiveTextSecondary(context))),
          ),
          Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: AppStyles.adaptiveTextPrimary(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                  textAlign: TextAlign.right)),
        ]),
      );
}

class _SubscriptionSelector extends StatelessWidget {
  final List<Subscription> subscriptions;
  final int? selectedId;
  final ValueChanged<int?> onChanged;

  const _SubscriptionSelector({
    required this.subscriptions,
    required this.selectedId,
    required this.onChanged,
  });

  String _validityText(Subscription s) {
    if (s.validUntil != null && s.validUntil!.isNotEmpty) {
      return 'До ${s.validUntil!}';
    }
    return '${s.remaining} ${s.remaining == 1 ? 'мойка' : s.remaining < 5 ? 'мойки' : 'моек'}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppStyles.cardDecorationFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_membership_rounded,
                  color: AppStyles.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Абонементы',
                style: TextStyle(
                  color: AppStyles.adaptiveTextPrimary(context),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Выберите абонемент, чтобы списать мойку бесплатно',
            style: TextStyle(
              color: AppStyles.adaptiveTextSecondary(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 10),
          ...subscriptions.map((s) {
            final selected = selectedId == s.id;
            return Material(
              color: selected
                  ? AppStyles.adaptivePrimaryBg(context)
                  : AppStyles.adaptiveInnerCard(context),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(selected ? null : s.id),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selected
                            ? AppStyles.primary
                            : AppStyles.adaptiveTextSecondary(context),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: TextStyle(
                                color: AppStyles.adaptiveTextPrimary(context),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _validityText(s),
                              style: TextStyle(
                                color: AppStyles.adaptiveTextSecondary(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (selectedId != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => onChanged(null),
                style: TextButton.styleFrom(
                  foregroundColor: AppStyles.adaptiveTextSecondary(context),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('Не использовать абонемент'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
