import 'appointment.dart';

class Service {
  final String id;
  String name;
  String description;
  int price;
  int durationMinutes;
  String category;
  bool isFavorite;
  bool isFromApi;

  Service({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.durationMinutes,
    required this.category,
    this.isFavorite = false,
    this.isFromApi = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'description': description,
    'price': price,
    'durationMinutes': durationMinutes,
    'category': category,
    'isFavorite': isFavorite ? 1 : 0,
    'isFromApi': isFromApi ? 1 : 0,
  };

  factory Service.fromMap(Map<String, dynamic> m) => Service(
    id: m['id']?.toString() ?? '',
    name: m['name'] ?? '',
    description: m['description'] ?? '',
    price: _parseInt(m['price']),
    durationMinutes: _parseInt(m['durationMinutes']),
    category: m['category'] ?? '',
    isFavorite: m['isFavorite'] == 1 || m['isFavorite'] == true,
    isFromApi: m['isFromApi'] == 1 || m['isFromApi'] == true,
  );

  static int _parseInt(dynamic v) =>
      v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  Service copyWith({
    String? name, String? description, int? price,
    int? durationMinutes, String? category, bool? isFavorite,
  }) => Service(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    price: price ?? this.price,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    category: category ?? this.category,
    isFavorite: isFavorite ?? this.isFavorite,
    isFromApi: isFromApi,
  );

  String get durationLabel {
    if (durationMinutes < 60) return '$durationMinutes мин';
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m == 0 ? '$h ч' : '$h ч $m мин';
  }
}

// ─── Конфигурация акции (что автоматически выбирается при записи) ────────────
class PromoConfig {
  final String washTypeName;
  final List<String> extras;
  final bool weekendOnly;
  final int discountPercent; // 0 = фиксированная цена, >0 = скидка % от basePrice типа мойки

  const PromoConfig({
    required this.washTypeName,
    required this.extras,
    this.weekendOnly = false,
    this.discountPercent = 0,
  });
}

PromoConfig? getPromoConfig(String promoName) {
  final n = promoName.toLowerCase();
  // Акция недели: комплекс + ароматизация
  if (n.contains('акция недели') || (n.contains('комплекс') && n.contains('аромат'))) {
    return const PromoConfig(washTypeName: 'complex', extras: ['Ароматизация']);
  }
  // Весенняя акция: мойка + воск
  if (n.contains('весен') || (n.contains('мойка') && n.contains('воск'))) {
    return const PromoConfig(washTypeName: 'basic', extras: ['Нанесение воска']);
  }
  // Выходной пакет: комплексная мойка -20%
  if (n.contains('выходной') || n.contains('выходн')) {
    return const PromoConfig(washTypeName: 'complex', extras: [], weekendOnly: true, discountPercent: 20);
  }
  // Пакет для внедорожников
  if (n.contains('внедорожник') || n.contains('пакет для')) {
    return const PromoConfig(washTypeName: 'complex',
        extras: ['Чернение шин', 'Обработка арок']);
  }
  return null;
}

// ─── Хелперы для расчёта времени акции ───────────────────────────────────────
const _extraDurationMinutes = {
  'Полировка стёкол': 20,  'Нанесение воска': 45,   'Нанесение силанта': 90,
  'Антидождь': 25,         'Чернение шин': 15,       'Ароматизация': 15,
  'Озонирование': 60,      'Удаление битума': 30,    'Химчистка салона': 180,
  'Пылесосная уборка': 25, 'Обработка арок': 20,     'Мойка двигателя': 60,
  'Химчистка кожи': 240,   'Детейлинг кузова': 360,
  'Керамическое покрытие': 480, 'Нанесение тефлона': 120,
};

/// Считает суммарное время акции в минутах:
/// базовое время типа мойки + extras акции (исключая авто-включённые в тип).
int getPromoDurationMinutes(String promoName) {
  final cfg = getPromoConfig(promoName);
  if (cfg == null) return 0;
  final washType = WashTypeX.fromString(cfg.washTypeName);
  final washIncluded = washType.includedExtras;
  int total = washType.durationMinutes;
  for (final e in cfg.extras) {
    if (!washIncluded.contains(e)) total += _extraDurationMinutes[e] ?? 0;
  }
  return total;
}

String getPromoDurationLabel(String promoName) {
  final mins = getPromoDurationMinutes(promoName);
  if (mins == 0) return '—';
  final h = mins ~/ 60;
  final m = mins % 60;
  if (h == 0) return '$m мин';
  return m == 0 ? '$h ч' : '$h ч $m мин';
}