import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../domain/entities/user.dart';
import '../../data/datasources/remote/auth_api.dart';
import '../../data/datasources/remote/log_api.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final _authApi = AuthApi();
  final _logApi = LogApi();
  final _notifications = NotificationService();

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

  static const _kUserKey = 'saved_user';
  final _storage = FlutterSecureStorage();

  Future<void> init() async {
    try {
      final json = await _storage.read(key: _kUserKey);
      final token = await _authApi.getToken();
      if (json != null && token != null) {
        _user = User.fromMap(jsonDecode(json));
        _notifications.updateTokenOnServer(_user!.username);
      }
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveUser(User user) async {
    try {
      await _storage.write(key: _kUserKey, value: jsonEncode(user.toMap()));
    } catch (_) {}
  }

  Future<void> _clearUser() async {
    try {
      await _storage.delete(key: _kUserKey);
      await _authApi.deleteToken();
    } catch (_) {}
  }

  Future<String?> login(String username, String password) async {
    _loading = true;
    notifyListeners();

    final user = await _authApi.login(username, password);

    _loading = false;
    if (user == null) {
      notifyListeners();
      await _logApi.createLog(username, 'Неудачная попытка входа', 'Логин: $username');
      return 'Неверный логин или пароль';
    }

    _user = user;
    await _saveUser(user);
    
    _notifications.updateTokenOnServer(user.username);

    notifyListeners();
    await _logApi.createLog(username, 'Вход в систему', 'Роль: ${user.role.name}');
    return null;
  }

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

    final user = await _authApi.register(username, password, 'client'); // Simplified, adjust role handling

    _loading = false;
    if (user == null) {
      notifyListeners();
      return 'Ошибка регистрации';
    }

    _user = user;
    await _saveUser(user);
    notifyListeners();
    await _logApi.createLog(username, 'Регистрация', 'Имя: ${user.displayName}');
    return null;
  }

  // Update profile logic... (omitted for brevity, you'll need to move it to AuthApi too)

  void logout() {
    final who = _user?.username ?? 'unknown';
    _logApi.createLog(who, 'Выход из системы', '');
    _user = null;
    _clearUser();
    notifyListeners();
  }
}