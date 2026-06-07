import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../providers/catalog_provider.dart';
import '../../providers/favorite_provider.dart';
import 'booking_wizard_screen.dart';

class ClientFavoritesScreen extends StatelessWidget {
  const ClientFavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.watch<CatalogProvider>();
    final favoriteProvider = context.watch<FavoriteProvider>();
    final favs = catalogProvider.services
        .where((s) => favoriteProvider.isServiceFavorite(s.id))
        .toList();

    if (favs.isEmpty) {
      return Container(
        color: AppStyles.adaptiveBgPage(context),
        child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
                color: AppStyles.primaryBg, shape: BoxShape.circle),
            child: const Icon(Icons.star_outline_rounded,
                size: 44, color: AppStyles.primary),
          ),
          const SizedBox(height: 16),
          Text('Нет избранных услуг',
              style: TextStyle(
                  color: AppStyles.adaptiveTextSecondary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          const Text('Добавляйте услуги при записи',
              style: AppStyles.bodyMedium),
        ])),
      );
    }

    return Container(
      color: AppStyles.adaptiveBgPage(context),
      child: ListView.builder(
        padding: AppStyles.pagePadding,
        itemCount: favs.length,
        itemBuilder: (ctx, i) {
          final s = favs[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: AppStyles.cardDecoration,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              onTap: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => const BookingWizardScreen())),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: s.isFromApi
                      ? AppStyles.favorite.withValues(alpha:0.12)
                      : AppStyles.primaryBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  s.isFromApi
                      ? Icons.local_offer_rounded
                      : Icons.local_car_wash,
                  color: s.isFromApi ? AppStyles.favorite : AppStyles.primary,
                  size: 22,
                ),
              ),
              title: Row(children: [
                Expanded(
                    child: Text(s.name,
                        style: TextStyle(
                            color: AppStyles.adaptiveTextPrimary(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w600))),
                if (s.isFromApi)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppStyles.favorite.withValues(alpha:0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('Акция',
                        style: TextStyle(
                            color: AppStyles.favorite,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
              ]),
              subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 3),
                    Text(s.category, style: AppStyles.bodySmall),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.access_time,
                          size: 12, color: AppStyles.adaptiveTextSecondary(context)),
                      const SizedBox(width: 4),
                      Text(s.durationLabel, style: AppStyles.bodySmall),
                      const SizedBox(width: 10),
                      Text('${s.price} ₽',
                          style: const TextStyle(
                              color: AppStyles.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ]),
              trailing: IconButton(
                icon: const Icon(Icons.star_rounded, color: AppStyles.favorite),
                onPressed: () => favoriteProvider.toggleServiceFavorite(s.id),
                tooltip: 'Убрать из избранного',
              ),
            ),
          );
        },
      ),
    );
  }
}
