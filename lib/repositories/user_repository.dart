import '../models/user.dart';
import '../services/database_service.dart';

class UserRepository {
  final _db = DatabaseService.instance;

  Future<User?> findByUsername(String username) async {
    final db = await _db.db;
    final rows = await db.query('users',
        where: 'username = ?',
        whereArgs: [username.toLowerCase().trim()]);
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<User?> findById(int id) async {
    final db = await _db.db;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  /// Логин — возвращает пользователя или null
  Future<User?> login(String username, String password) async {
    final user = await findByUsername(username);
    if (user == null) return null;
    if (!User.checkPassword(password, user.passwordHash)) return null;
    return user;
  }

  /// Регистрация — возвращает ошибку или null если успешно
  Future<String?> register({
    required String username,
    required String password,
    required String displayName,
    String phone = '',
    String carModel = '',
    String carNumber = '',
  }) async {
    if (username.trim().isEmpty) return 'Введите логин';
    if (password.length < 4) return 'Пароль минимум 4 символа';
    if (displayName.trim().isEmpty) return 'Введите имя';

    final existing = await findByUsername(username);
    if (existing != null) return 'Пользователь уже существует';

    final db = await _db.db;
    await db.insert('users', {
      'username': username.toLowerCase().trim(),
      'passwordHash': User.hashPassword(password),
      'role': 'client',
      'displayName': displayName.trim(),
      'phone': phone.trim(),
      'carModel': carModel.trim(),
      'carNumber': carNumber.trim(),
      'createdAt': DateTime.now().toIso8601String(),
      'isFavoriteAdmin': 0,
    });
    return null;
  }

  Future<List<User>> getAllClients() async {
    final db = await _db.db;
    final rows = await db.query('users',
        where: 'role = ?', whereArgs: ['client'],
        orderBy: 'createdAt DESC');
    return rows.map(User.fromMap).toList();
  }

  Future<void> updateProfile(User user) async {
    final db = await _db.db;
    await db.update('users', user.toMap(),
        where: 'id = ?', whereArgs: [user.id]);
  }

  Future<void> deleteUser(int id) async {
    final db = await _db.db;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }
}
