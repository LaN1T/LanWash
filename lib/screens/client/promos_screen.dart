import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../app_styles.dart';
import '../../models/service.dart';
import '../../providers/app_provider.dart';
import 'service_detail_screen.dart';

class PromosScreen extends StatelessWidget {
  const PromosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final promos   = provider.services.where((s) => s.isFromApi).toList();

    return Scaffold(
      backgroundColor: AppStyles.bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppStyles.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppStyles.border),
        ),
        title: const Text('Акции и спецпредложения',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                color: AppStyles.textPrimary)),
      ),
      body: provider.loadingApi && promos.isEmpty
          ? const Center(child: CircularProgressIndicator(
              color: AppStyles.primary))
          : promos.isEmpty
          ? Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                      color: AppStyles.primaryBg, shape: BoxShape.circle),
                  child: const Icon(Icons.local_offer_outlined,
                      size: 44, color: AppStyles.primary),
                ),
                const SizedBox(height: 16),
                const Text('Нет активных акций',
                    style: TextStyle(color: AppStyles.textSecondary,
                        fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                const Text('Загляните позже',
                    style: AppStyles.bodyMedium),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: promos.length,
              itemBuilder: (ctx, i) => _PromoCard(
                service: promos[i],
                isFavorite: provider.isServiceFavorite(promos[i].id),
                onFavorite: () => provider.toggleServiceFavorite(promos[i].id),
              ),
            ),
    );
  }
}

class _PromoCard extends StatelessWidget {
  final Service service;
  final bool isFavorite;
  final VoidCallback onFavorite;
  const _PromoCard({required this.service, required this.isFavorite,
      required this.onFavorite});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => ServiceDetailScreen(service: service))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: AppStyles.cardDecoration,
        child: Row(children: [
          Container(
            width: 5,
            height: 110,
            decoration: BoxDecoration(
              gradient: AppStyles.primaryGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppStyles.primaryGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('АКЦИЯ', style: TextStyle(
                        color: Colors.white, fontSize: 10,
                        fontWeight: FontWeight.bold)),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: onFavorite,
                    child: Icon(
                      isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: isFavorite ? AppStyles.favorite : AppStyles.textSecondary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppStyles.textSecondary),
                ]),
                const SizedBox(height: 8),
                Text(service.name, style: const TextStyle(
                    color: AppStyles.textPrimary, fontSize: 15,
                    fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(service.description, style: AppStyles.bodySmall,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 10),
                Row(children: [
                  Text('${service.price} ₽', style: const TextStyle(
                      color: AppStyles.primary, fontSize: 16,
                      fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  const Icon(Icons.access_time_rounded,
                      size: 13, color: AppStyles.textSecondary),
                  const SizedBox(width: 3),
                  Text(service.durationLabel, style: AppStyles.bodySmall),
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
