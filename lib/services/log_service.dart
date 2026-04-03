import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';
import '../repositories/log_repository.dart';

/// Константы действий — чтобы не писать строки вручную везде
class LogAction {
  static const loginSuccess  = 'Вход в систему';
  static const loginFail     = 'Неудачная попытка входа';
  static const logout        = 'Выход из системы';
  static const register      = 'Регистрация';
  static const createAppt    = 'Создание записи';
  static const editAppt      = 'Редактирование записи';
  static const deleteAppt    = 'Удаление записи';
  static const favService    = 'Добавлено в избранное';
  static const unfavService  = 'Убрано из избранного';
  static const favExtra      = 'Доп. услуга добавлена в избранное';
  static const unfavExtra    = 'Доп. услуга убрана из избранного';
  static const updateProfile = 'Обновление профиля';
}

class LogService {
  static final LogService _instance = LogService._();
  static LogService get instance => _instance;
  LogService._();

  final _repo = LogRepository();

  Future<void> log(String username, String action, String details) async {
    try {
      await _repo.insert(LogEntry(
        username: username.toLowerCase(),
        action: action,
        details: details,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      // Логирование не должно ломать основной поток
      debugPrint('[LogService] Ошибка записи лога: $e');
    }
  }

  Future<List<LogEntry>> getAll({int limit = 200}) => _repo.getAll(limit: limit);
  Future<List<LogEntry>> getByUser(String username) => _repo.getByUser(username);
  Future<void> clearAll() => _repo.clearAll();
}
