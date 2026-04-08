import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/service.dart';
import '../../providers/app_provider.dart';
import 'booking_wizard_screen.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Service service;
  const ServiceDetailScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final s = provider.services.firstWhere(
      (x) => x.id == service.id, orElse: () => service,
    );
    final promoConfig = s.isFromApi ? getPromoConfig(s.name) : null;

    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppStyles.border)),
        title: Text(s.isFromApi ? 'Акция' : 'Услуга'),
        actions: [
          IconButton(
            icon: Icon(provider.isServiceFavorite(s.id) ? Icons.star_rounded : Icons.star_outline_rounded,
                color: provider.isServiceFavorite(s.id) ? AppStyles.favorite : AppStyles.textSecondary),
            onPressed: () => provider.toggleServiceFavorite(s.id),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppStyles.pagePadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Заголовок ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: s.isFromApi
                ? AppStyles.primaryCardDecoration
                : AppStyles.cardDecoration,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (s.isFromApi)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.local_offer, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text('Специальное предложение',
                        style: TextStyle(color: Colors.white, fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              Text(s.name, style: TextStyle(
                  color: s.isFromApi ? Colors.white : AppStyles.textPrimary,
                  fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(s.category, style: TextStyle(
                  color: s.isFromApi
                      ? Colors.white70 : AppStyles.textSecondary,
                  fontSize: 14)),
              const SizedBox(height: 16),
              Row(children: [
                _Stat(Icons.payments_outlined, 'Стоимость',
                    '${s.price} ₽', s.isFromApi),
                const SizedBox(width: 28),
                _Stat(Icons.access_time_rounded, 'Время',
                    s.isFromApi ? getPromoDurationLabel(s.name) : s.durationLabel, s.isFromApi),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

          // ── Что входит (для акций) ────────────────────────────────────
          if (s.isFromApi && promoConfig != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppStyles.cardDecoration,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.check_circle_rounded,
                      color: AppStyles.primary, size: 18),
                  SizedBox(width: 8),
                  Text('Что входит в акцию',
                      style: TextStyle(color: AppStyles.textPrimary,
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 12),
                _IncludedItem(_washLabel(promoConfig.washTypeName)),
                ...promoConfig.extras.map((e) => _IncludedItem(e)),
              ]),
            ),
            const SizedBox(height: 14),
          ],

          // ── Описание ────────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.cardDecoration,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Описание', style: AppStyles.label),
              const SizedBox(height: 10),
              Text(s.description,
                  style: AppStyles.bodyLarge.copyWith(height: 1.6)),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Кнопки ──────────────────────────────────────────────────────
          if (s.isFromApi && promoConfig != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today_rounded, size: 18),
                label: const Text('Записаться по акции'),
                style: AppStyles.primaryButton,
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => BookingWizardScreen(promoService: s),
                )),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(provider.isServiceFavorite(s.id)
                  ? Icons.star_rounded : Icons.star_outline_rounded),
              label: Text(provider.isServiceFavorite(s.id)
                  ? 'Убрать из избранного' : 'Добавить в избранное'),
              style: AppStyles.outlineButton,
              onPressed: () => provider.toggleServiceFavorite(s.id),
            ),
          ),
        ]),
      ),
    );
  }

  String _washLabel(String name) => switch (name) {
    'basic'   => 'Базовая мойка кузова',
    'complex' => 'Комплексная мойка + салон',
    'premium' => 'Премиум мойка',
    _         => name,
  };
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool onDark;
  const _Stat(this.icon, this.label, this.value, this.onDark);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(
          color: onDark ? Colors.white60 : AppStyles.textSecondary,
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Row(children: [
        Icon(icon, size: 16, color: onDark ? Colors.white : AppStyles.primary),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(
            color: onDark ? Colors.white : AppStyles.primary,
            fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    ],
  );
}

class _IncludedItem extends StatelessWidget {
  final String text;
  const _IncludedItem(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(
        width: 20, height: 20,
        decoration: const BoxDecoration(
            color: AppStyles.primaryBg, shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, size: 12, color: AppStyles.primary),
      ),
      const SizedBox(width: 10),
      Text(text, style: const TextStyle(color: AppStyles.textPrimary, fontSize: 14)),
    ]),
  );
}