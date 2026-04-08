import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  static const _kUserKey = 'saved_user';

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_kUserKey);
      if (json != null) {
        _user = User.fromMap(jsonDecode(json));
      }
    } catch (_) {}
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kUserKey, jsonEncode(user.toMap()));
    } catch (_) {}
  }

  Future<void> _clearUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kUserKey);
    } catch (_) {}
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
    await _saveUser(user);
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
    await _saveUser(_user!);
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
      await _saveUser(updated);
      notifyListeners();
      await _api.createLog(updated.username, 'Обновление профиля', 'Имя: ${updated.displayName}');
    }
  }

  void logout() {
    final who = _user?.username ?? 'unknown';
    _api.createLog(who, 'Выход из системы', '');
    _user = null;
    _clearUser();
    notifyListeners();
  }
}