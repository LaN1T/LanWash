import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/service.dart';
import '../../providers/app_provider.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Service service;
  const ServiceDetailScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final s = provider.services.firstWhere(
      (x) => x.id == service.id, orElse: () => service,
    );

    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppStyles.border)),
        title: const Text('Услуга'),
        actions: [
          IconButton(
            icon: Icon(provider.isServiceFavorite(s.id)
                    ? Icons.star_rounded : Icons.star_outline_rounded,
                color: provider.isServiceFavorite(s.id)
                    ? AppStyles.favorite : AppStyles.textSecondary),
            onPressed: () => provider.toggleServiceFavorite(s.id),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppStyles.pagePadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: AppStyles.cardDecoration,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.name, style: const TextStyle(
                  color: AppStyles.textPrimary,
                  fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(s.category, style: const TextStyle(
                  color: AppStyles.textSecondary, fontSize: 14)),
              const SizedBox(height: 16),
              Row(children: [
                _Stat(Icons.payments_outlined, 'Стоимость', '${s.price} ₽'),
                const SizedBox(width: 28),
                _Stat(Icons.access_time_rounded, 'Время', s.durationLabel),
              ]),
            ]),
          ),
          const SizedBox(height: 14),

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
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _Stat(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
          color: AppStyles.textSecondary,
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 4),
      Row(children: [
        Icon(icon, size: 16, color: AppStyles.primary),
        const SizedBox(width: 6),
        Text(value, style: const TextStyle(
            color: AppStyles.primary,
            fontSize: 18, fontWeight: FontWeight.bold)),
      ]),
    ],
  );
}
