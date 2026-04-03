import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  final _api = ApiService();

  User? _user;
  bool _initialized = false;
  bool _loading = false;

  User?   get user        => _user;
  bool    get initialized => _initialized;
  bool    get loading     => _loading;
  bool    get isLoggedIn  => _user != null;
  bool    get isClient    => _user?.role == UserRole.client;
  bool    get isAdmin     => _user?.role == UserRole.admin;
  bool    get isWasher    => _user?.role == UserRole.washer;
  String  get username    => _user?.displayName ?? '';
  String  get userLogin   => _user?.username ?? '';

  Future<void> init() async {
    _initialized = true;
    notifyListeners();
  }

  /// Возвращает null при успехе, иначе текст ошибки
  Future<String?> login(String username, String password) async {
    _loading = true;
    notifyListeners();

    final user = await _api.login(username, password);

    _loading = false;
    if (user == null) {
      notifyListeners();
      await _api.createLog(username, 'Неудачная попытка входа', 'Логин: $username');
      return 'Неверный логин или пароль';
    }

    _user = user;
    notifyListeners();
    await _api.createLog(username, 'Вход в систему', 'Роль: ${user.role.name}');
    return null;
  }

  /// Регистрация нового клиента
  Future<String?> register({
    required String username,
    required String password,
    required String displayName,
    String phone = '',
    String carModel = '',
    String carNumber = '',
  }) async {
    _loading = true;
    notifyListeners();

    final result = await _api.register(
      username: username,
      password: password,
      displayName: displayName,
      phone: phone,
      carModel: carModel,
      carNumber: carNumber,
    );

    _loading = false;
    if (result == null || result.containsKey('error')) {
      notifyListeners();
      return result?['error'] ?? 'Ошибка регистрации';
    }

    // Автологин после регистрации
    _user = User.fromMap(result['user']);
    notifyListeners();
    await _api.createLog(username, 'Регистрация', 'Имя: ${_user?.displayName ?? displayName}');
    return null;
  }

  Future<void> updateProfile({
    String? displayName,
    String? phone,
    String? carModel,
    String? carNumber,
    String? newPassword,
  }) async {
    if (_user == null) return;
    final updated = await _api.updateProfile(
      _user!.id!,
      displayName: displayName,
      phone: phone,
      carModel: carModel,
      carNumber: carNumber,
      newPassword: newPassword,
    );
    if (updated != null) {
      _user = updated;
      notifyListeners();
      await _api.createLog(updated.username, 'Обновление профиля', 'Имя: ${updated.displayName}');
    }
  }

  void logout() {
    final who = _user?.username ?? 'unknown';
    _api.createLog(who, 'Выход из системы', '');
    _user = null;
    notifyListeners();
  }
}
