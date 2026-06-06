import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/service.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/favorite_provider.dart';
import 'add_edit_service_screen.dart';

class ServiceDetailScreen extends StatelessWidget {
  final Service service;
  const ServiceDetailScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.watch<CatalogProvider>();
    final favoriteProvider = context.watch<FavoriteProvider>();
    final s = catalogProvider.services.firstWhere(
      (x) => x.id == service.id,
      orElse: () => service,
    );

    return Scaffold(
      backgroundColor: AppStyles.background,
      appBar: AppBar(
        backgroundColor: AppStyles.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Детали услуги',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(
                favoriteProvider.isServiceFavorite(s.id)
                    ? Icons.star
                    : Icons.star_border,
                color: favoriteProvider.isServiceFavorite(s.id)
                    ? AppStyles.favorite
                    : Colors.white70),
            onPressed: () => favoriteProvider.toggleServiceFavorite(s.id),
          ),
          if (!s.isFromApi)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AddEditServiceScreen(service: s))),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: AppStyles.pagePadding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity,
            decoration: AppStyles.cardDecoration,
            padding: AppStyles.cardPadding,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (s.isFromApi)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppStyles.apiTag.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.local_offer, size: 14, color: AppStyles.apiTag),
                    SizedBox(width: 4),
                    Text('Акция от партнёров',
                        style: TextStyle(
                            color: AppStyles.apiTag,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              Text(s.name, style: AppStyles.headingLarge),
              const SizedBox(height: 6),
              Text(s.category, style: AppStyles.bodyMedium),
              const SizedBox(height: 16),
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Стоимость', style: AppStyles.label),
                  Text('${s.price} ₽', style: AppStyles.price),
                ]),
                const SizedBox(width: 32),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Время', style: AppStyles.label),
                  Text(s.durationLabel,
                      style: AppStyles.headingMedium
                          .copyWith(color: AppStyles.primary)),
                ]),
              ]),
            ]),
          ),
          const SizedBox(height: 16),
          _label('Описание услуги'),
          Container(
            width: double.infinity,
            decoration: AppStyles.cardDecoration,
            padding: AppStyles.cardPadding,
            child: Text(s.description,
                style: AppStyles.bodyLarge.copyWith(height: 1.5)),
          ),
          const SizedBox(height: 24),
          if (!s.isFromApi) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Редактировать услугу'),
                style: AppStyles.primaryButton,
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => AddEditServiceScreen(service: s))),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(favoriteProvider.isServiceFavorite(s.id)
                  ? Icons.star
                  : Icons.star_border),
              label: Text(favoriteProvider.isServiceFavorite(s.id)
                  ? 'Убрать из избранного'
                  : 'Добавить в избранное'),
              style: AppStyles.outlineButton,
              onPressed: () => favoriteProvider.toggleServiceFavorite(s.id),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: AppStyles.label
                .copyWith(fontSize: 13, color: AppStyles.primary)),
      );
}
