import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/promo.dart';
import '../../providers/catalog_provider.dart';
import 'booking_wizard_screen.dart';

class PromosScreen extends StatelessWidget {
  const PromosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.watch<CatalogProvider>();
    final promos = catalogProvider.promos;

    return Scaffold(
      backgroundColor: AppStyles.adaptiveBgPage(context),
      appBar: AppBar(
        backgroundColor: AppStyles.adaptiveCard(context),
        foregroundColor: AppStyles.adaptiveTextPrimary(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text('Акции и спецпредложения',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppStyles.adaptiveTextPrimary(context))),
      ),
      body: promos.isEmpty
          ? Center(
              child:
                  Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_offer_outlined,
                    size: 44, color: AppStyles.primary),
                const SizedBox(height: 16),
                Text('Нет активных акций',
                    style: TextStyle(
                        color: AppStyles.adaptiveTextSecondary(context), fontSize: 16)),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: promos.length,
              itemBuilder: (ctx, i) => _PromoCard(promo: promos[i]),
            ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Promo promo;
  const _PromoCard({required this.promo});

  @override
  Widget build(BuildContext context) {
    final catalogProvider = context.watch<CatalogProvider>();
    final wt = catalogProvider.washTypeById(promo.washTypeId);
    final displayPrice = promo.discountPercent > 0 && wt != null
        ? wt.basePrice * (100 - promo.discountPercent) ~/ 100
        : promo.price;
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => BookingWizardScreen(initialPromo: promo))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: AppStyles.cardDecorationFor(context),
        child: Row(children: [
          Container(
            width: 5,
            height: 110,
            decoration: const BoxDecoration(
              gradient: AppStyles.primaryGradient,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: AppStyles.primaryGradient,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('АКЦИЯ',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppStyles.adaptiveTextSecondary(context)),
                    ]),
                    const SizedBox(height: 8),
                    Text(promo.name,
                        style: TextStyle(
                            color: AppStyles.adaptiveTextPrimary(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(promo.description,
                        style: AppStyles.adaptiveBodySmall(context),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 10),
                    Row(children: [
                      Text('$displayPrice ₽',
                          style: const TextStyle(
                              color: AppStyles.primary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded,
                          size: 13, color: AppStyles.adaptiveTextSecondary(context)),
                      const SizedBox(width: 3),
                      Text('${promo.duration} мин', style: AppStyles.adaptiveBodySmall(context)),
                    ]),
                  ]),
            ),
          ),
          const SizedBox(width: 14),
        ]),
      ),
    );
  }
}
