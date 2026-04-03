import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../models/user.dart';
import '../repositories/user_repository.dart';
import '../services/database_service.dart';
import '../services/log_service.dart';

class AuthProvider extends ChangeNotifier {
  final _repo = UserRepository();

  User? _user;
  bool _initialized = false;
  bool _loading = false;

  User?   get user        => _user;
  bool    get initialized => _initialized;
  bool    get loading     => _loading;
  bool    get isLoggedIn  => _user != null;
  bool    get isClient    => _user?.role == UserRole.client;
  bool    get isAdmin     => _user?.role == UserRole.admin;
  String  get username    => _user?.displayName ?? '';
  String  get userLogin   => _user?.username ?? '';

  Future<void> init() async {
    // Инициализируем БД при старте
    await DatabaseService.instance.db;
    _initialized = true;
    notifyListeners();
  }

  /// Возвращает null при успехе, иначе текст ошибки
  Future<String?> login(String username, String password) async {
    _loading = true;
    notifyListeners();

    final user = await _repo.login(username, password);

    _loading = false;
    if (user == null) {
      notifyListeners();
      await LogService.instance.log(username, LogAction.loginFail,
          'Логин: $username');
      return 'Неверный логин или пароль';
    }

    _user = user;
    notifyListeners();
    await LogService.instance.log(username, LogAction.loginSuccess,
        'Роль: ${user.role.name}');
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

    final error = await _repo.register(
      username: username,
      password: password,
      displayName: displayName,
      phone: phone,
      carModel: carModel,
      carNumber: carNumber,
    );

    _loading = false;
    if (error != null) {
      notifyListeners();
      return error;
    }

    // Автологин после регистрации
    _user = await _repo.findByUsername(username);
    notifyListeners();
    await LogService.instance.log(username, LogAction.register,
        'Имя: ${_user?.displayName ?? displayName}');
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
    final updated = _user!.copyWith(
      displayName: displayName,
      phone: phone,
      carModel: carModel,
      carNumber: carNumber,
      passwordHash: newPassword != null
          ? User.hashPassword(newPassword) : null,
    );
    await _repo.updateProfile(updated);
    _user = updated;
    notifyListeners();
    await LogService.instance.log(updated.username, LogAction.updateProfile,
        'Имя: ${updated.displayName}');
  }

  void logout() {
    final who = _user?.username ?? 'unknown';
    LogService.instance.log(who, LogAction.logout, '');
    _user = null;
    notifyListeners();
  }
}
