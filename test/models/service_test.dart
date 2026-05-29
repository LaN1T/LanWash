import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/models/service.dart';

void main() {
  group('Service', () {
    test('fromMap parses int fields correctly', () {
      final s = Service.fromMap({
        'id': 's1',
        'name': 'Мойка',
        'description': 'Быстрая',
        'price': 500,
        'durationMinutes': 30,
        'category': 'Мойка',
        'isFavorite': 1,
        'isFromApi': true,
      });

      expect(s.id, equals('s1'));
      expect(s.price, equals(500));
      expect(s.durationMinutes, equals(30));
      expect(s.isFavorite, isTrue);
      expect(s.isFromApi, isTrue);
    });

    test('fromMap parses string numbers', () {
      final s = Service.fromMap({
        'id': 's2',
        'name': 'Полировка',
        'description': '',
        'price': '1500',
        'durationMinutes': '120',
        'category': 'Детейлинг',
        'isFavorite': 0,
        'isFromApi': false,
      });

      expect(s.price, equals(1500));
      expect(s.durationMinutes, equals(120));
      expect(s.isFavorite, isFalse);
    });

    test('toMap serializes correctly', () {
      final s = Service(
        id: 's3',
        name: 'Тест',
        description: 'desc',
        price: 100,
        durationMinutes: 15,
        category: 'cat',
        isFavorite: true,
      );

      final map = s.toMap();
      expect(map['id'], equals('s3'));
      expect(map['price'], equals(100));
      expect(map['isFavorite'], isTrue);
    });

    test('durationLabel formats minutes', () {
      expect(Service(id: '', name: '', description: '', price: 0, durationMinutes: 45, category: '').durationLabel, equals('45 мин'));
    });

    test('durationLabel formats hours and minutes', () {
      expect(Service(id: '', name: '', description: '', price: 0, durationMinutes: 90, category: '').durationLabel, equals('1 ч 30 мин'));
    });

    test('durationLabel formats whole hours', () {
      expect(Service(id: '', name: '', description: '', price: 0, durationMinutes: 120, category: '').durationLabel, equals('2 ч'));
    });

    test('copyWith updates fields', () {
      final s = Service(id: 'x', name: 'Old', description: '', price: 100, durationMinutes: 30, category: '');
      final updated = s.copyWith(name: 'New', price: 200);
      expect(updated.name, equals('New'));
      expect(updated.price, equals(200));
      expect(updated.durationMinutes, equals(30));
    });
  });
}
