import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final _api = ApiService();
  final _notifications = NotificationService();

  User? _user;
  bool _initialized = false;
  bool _loading = false;
  String? _errorMessage;

  User?   get user         => _user;
  bool    get initialized  => _initialized;
  bool    get loading      => _loading;
  String? get errorMessage => _errorMessage;
  bool    get isLoggedIn   => _user != null;
  bool    get isClient     => _user?.role == UserRole.client;
  bool    get isAdmin      => _user?.role == UserRole.admin;
  bool    get isWasher     => _user?.role == UserRole.washer;
  String  get username     => _user?.displayName ?? '';
  String  get userLogin    => _user?.username ?? '';

  static const _kUserKey = 'saved_user';
  final _storage = const FlutterSecureStorage();

  void clearError() {
    _errorMessage = null;
  }

  Future<void> init() async {
    try {
      final json = await _storage.read(key: _kUserKey);
      final token = await ApiService.getToken();
      if (json != null && token != null) {
        _user = User.fromMap(jsonDecode(json));
        _notifications.updateTokenOnServer(_user!.username);
      }
    } catch (e, st) {
      debugPrint('[AuthProvider.init] error: $e\n$st');
      _errorMessage = 'Ошибка загрузки сессии';
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveUser(User user) async {
    try {
      await _storage.write(key: _kUserKey, value: jsonEncode(user.toMap()));
    } catch (e, st) {
      debugPrint('[AuthProvider._saveUser] error: $e\n$st');
    }
  }

  Future<void> _clearUser() async {
    try {
      await _storage.delete(key: _kUserKey);
      await ApiService.deleteToken();
    } catch (e, st) {
      debugPrint('[AuthProvider._clearUser] error: $e\n$st');
    }
  }

  /// Возвращает null при успехе, иначе текст ошибки
  Future<String?> login(String username, String password) async {
    clearError();
    _loading = true;
    notifyListeners();

    try {
      final user = await _api.login(username, password);

      _loading = false;
      if (user == null) {
        notifyListeners();
        await _api.createLog(username, 'Неудачная попытка входа', 'Логин: $username');
        return 'Неверный логин или пароль';
      }

      _user = user;
      await _saveUser(user);
      _notifications.updateTokenOnServer(user.username);

      notifyListeners();
      await _api.createLog(username, 'Вход в систему', 'Роль: ${user.role.name}');
      return null;
    } catch (e, st) {
      _loading = false;
      debugPrint('[AuthProvider.login] error: $e\n$st');
      _errorMessage = 'Ошибка сети. Проверьте подключение.';
      notifyListeners();
      return _errorMessage;
    }
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
    clearError();
    _loading = true;
    notifyListeners();

    try {
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
    } catch (e, st) {
      _loading = false;
      debugPrint('[AuthProvider.register] error: $e\n$st');
      _errorMessage = 'Ошибка сети. Проверьте подключение.';
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<String?> updateProfile({
    String? displayName,
    String? phone,
    String? carModel,
    String? carNumber,
    String? newPassword,
  }) async {
    if (_user == null) return null;
    clearError();

    try {
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
        return null;
      }
      return 'Ошибка обновления профиля';
    } catch (e, st) {
      debugPrint('[AuthProvider.updateProfile] error: $e\n$st');
      _errorMessage = 'Ошибка сети. Проверьте подключение.';
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<void> logout() async {
    debugPrint('[AuthProvider.logout] called');
    final who = _user?.username ?? 'unknown';
    try {
      await _api.createLog(who, 'Выход из системы', '');
    } catch (e) {
      debugPrint('[AuthProvider.logout] createLog error: $e');
    }
    _user = null;
    await _clearUser();
    notifyListeners();
  }
}