import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/models/user.dart';

void main() {
  group('User', () {
    test('fromMap parses all fields', () {
      final user = User.fromMap({
        'id': 1,
        'username': 'testuser',
        'passwordHash': 'hash123',
        'role': 'admin',
        'displayName': 'Test User',
        'phone': '+7999',
        'carModel': 'Camry',
        'carNumber': 'А123БВ77',
        'createdAt': '2024-01-01T00:00:00Z',
        'isFavoriteAdmin': 1,
      });

      expect(user.id, equals(1));
      expect(user.username, equals('testuser'));
      expect(user.role, equals(UserRole.admin));
      expect(user.displayName, equals('Test User'));
      expect(user.isFavoriteAdmin, isTrue);
    });

    test('fromMap defaults missing fields', () {
      final user = User.fromMap({
        'username': 'min',
        'passwordHash': 'h',
        'role': 'client',
        'createdAt': null,
      });

      expect(user.id, isNull);
      expect(user.phone, isEmpty);
      expect(user.carModel, isEmpty);
      expect(user.isFavoriteAdmin, isFalse);
    });

    test('toMap serializes correctly without passwordHash', () {
      final user = User(
        id: 2,
        username: 'u',
        passwordHash: 'h',
        role: UserRole.washer,
        displayName: 'Washer',
        createdAt: DateTime(2024, 6, 15),
        isFavoriteAdmin: true,
      );

      final map = user.toMap();
      expect(map['id'], equals(2));
      expect(map['role'], equals('washer'));
      expect(map['isFavoriteAdmin'], equals(1));
      // Security: passwordHash must never be serialized to client storage
      expect(map.containsKey('passwordHash'), isFalse);
    });

    test('copyWith updates selected fields', () {
      final user = User(
        username: 'u',
        passwordHash: 'h',
        role: UserRole.client,
        displayName: 'Old',
        createdAt: DateTime.now(),
      );
      final updated = user.copyWith(displayName: 'New');
      expect(updated.displayName, equals('New'));
      expect(updated.username, equals('u'));
    });
  });
}
