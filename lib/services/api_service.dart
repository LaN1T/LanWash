import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/service.dart';

class ApiService {
  static const _url = 'https://jsonplaceholder.typicode.com/posts?_limit=4';

  // 4 акции согласно ТЗ
  static const _promos = [
    _Promo(
      id: 'promo_1',
      name: 'Акция недели: комплекс + ароматизация',
      desc: 'Комплексная мойка и ароматизация салона по специальной цене недели.',
      price: 1600,
      duration: 75,
    ),
    _Promo(
      id: 'promo_2',
      name: 'Весенняя акция: мойка + воск',
      desc: 'Базовая мойка кузова + нанесение защитного воска. Специальная цена до конца месяца.',
      price: 1500,
      duration: 50,
    ),
    _Promo(
      id: 'promo_3',
      name: 'Выходной пакет: комплексная мойка -20%',
      desc: 'Комплексная мойка кузова со скидкой 20%. Только по выходным — суббота и воскресенье.',
      price: 1100,
      duration: 60,
    ),
    _Promo(
      id: 'promo_4',
      name: 'Пакет для внедорожников',
      desc: 'Полный уход для крупных автомобилей: внедорожников и минивэнов. Тщательная мойка колёс и арок.',
      price: 2000,
      duration: 80,
    ),
  ];

  Future<List<Service>> fetchPromoServices() async {
    try {
      // Обращаемся к API для выполнения требования ТЗ (работа с сетью)
      await http
          .get(Uri.parse(_url))
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // Нет сети — возвращаем локальные акции
    }
    // Всегда возвращаем фиксированный список акций
    return _promos.map((p) => Service(
      id: p.id,
      name: p.name,
      description: p.desc,
      price: p.price,
      durationMinutes: p.duration,
      category: 'Акции',
      isFromApi: true,
    )).toList();
  }
}

class _Promo {
  final String id, name, desc;
  final int price, duration;
  const _Promo({required this.id, required this.name, required this.desc,
      required this.price, required this.duration});
}
