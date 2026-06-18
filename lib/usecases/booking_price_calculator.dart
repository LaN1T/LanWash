import '../models/promo.dart';
import '../models/service.dart';
import '../models/wash_type.dart';

/// Pure business logic for calculating booking prices and durations.
///
/// No Flutter dependencies — can be unit-tested in isolation.
class BookingPriceCalculator {
  final WashType? washType;
  final Set<String> extras;
  final Promo? promo;
  final List<Service> services;

  const BookingPriceCalculator({
    required this.washType,
    required this.extras,
    required this.promo,
    required this.services,
  });

  bool get isPromo => promo != null;

  Set<String> get lockedExtras => <String>{
        ...?washType?.includedExtraIds,
        if (isPromo) ...promo!.includedExtraIds,
      };

  Service? _serviceById(String id) {
    try {
      return services.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }

  int _extraPrice(String id) => _serviceById(id)?.price ?? 0;
  int _extraDuration(String id) => _serviceById(id)?.durationMinutes ?? 0;

  /// Total duration in minutes.
  int get duration {
    int total = washType?.durationMinutes ?? 30;
    final locked = lockedExtras;
    for (final id in extras) {
      if (!locked.contains(id)) {
        total += _extraDuration(id);
      }
    }
    return total;
  }

  /// Human-readable duration label.
  String get durationLabel {
    int total = washType?.durationMinutes ?? 0;
    final washIncluded = washType?.includedExtraIds.toSet() ?? <String>{};
    for (final id in extras) {
      if (washIncluded.contains(id)) continue;
      total += _extraDuration(id);
    }

    final d = total ~/ (24 * 60);
    final h = (total % (24 * 60)) ~/ 60;
    final m = total % 60;

    final parts = <String>[];
    if (d > 0) parts.add('$d д');
    if (h > 0) parts.add('$h ч');
    if (m > 0) parts.add('$m мин');

    return parts.isEmpty ? '0 мин' : parts.join(' ');
  }

  /// Price without any promo.
  int get regularPrice {
    int p = washType?.basePrice ?? 0;
    final washIncluded = washType?.includedExtraIds.toSet() ?? <String>{};
    for (final id in extras) {
      if (!washIncluded.contains(id)) p += _extraPrice(id);
    }
    return p;
  }

  /// Price of extras only (excluding included ones).
  int get extrasPrice {
    int p = 0;
    final locked = lockedExtras;
    for (final id in extras) {
      if (!locked.contains(id)) p += _extraPrice(id);
    }
    return p;
  }

  /// Promo base price (wash type price with discount).
  int get promoBasePrice {
    if (!isPromo) return 0;
    if (promo!.discountPercent > 0) {
      final base = washType?.basePrice ?? 0;
      return base * (100 - promo!.discountPercent) ~/ 100;
    }
    return promo!.price;
  }

  /// Final price after promo.
  int get finalPrice => isPromo ? promoBasePrice + extrasPrice : regularPrice;

  bool get hasDiscount => isPromo && finalPrice < regularPrice;
}
