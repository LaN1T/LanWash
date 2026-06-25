class PromoEffectivenessReport {
  final List<PromoEffectivenessEntry> items;

  PromoEffectivenessReport({required this.items});

  factory PromoEffectivenessReport.fromJson(Map<String, dynamic> json) {
    return PromoEffectivenessReport(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => PromoEffectivenessEntry.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class PromoEffectivenessEntry {
  final String? promoId;
  final String promoName;
  final int usesCount;
  final double revenue;
  final double discountTotal;

  PromoEffectivenessEntry({
    this.promoId,
    required this.promoName,
    required this.usesCount,
    required this.revenue,
    required this.discountTotal,
  });

  factory PromoEffectivenessEntry.fromJson(Map<String, dynamic> json) {
    return PromoEffectivenessEntry(
      promoId: json['promo_id'] as String?,
      promoName: json['promo_name'] as String,
      usesCount: (json['uses_count'] as num).toInt(),
      revenue: (json['revenue'] as num).toDouble(),
      discountTotal: (json['discount_total'] as num).toDouble(),
    );
  }
}
