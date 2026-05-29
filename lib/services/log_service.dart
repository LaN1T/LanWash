import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';
import 'api_service.dart';

/// Константы действий — чтобы не писать строки вручную везде
class LogAction {
  static const loginSuccess = 'Вход в систему';
  static const loginFail = 'Неудачная попытка входа';
  static const logout = 'Выход из системы';
  static const register = 'Регистрация';
  static const createAppt = 'Создание записи';
  static const editAppt = 'Редактирование записи';
  static const deleteAppt = 'Удаление записи';
  static const favService = 'Добавлено в избранное';
  static const unfavService = 'Убрано из избранного';
  static const favExtra = 'Доп. услуга добавлена в избранное';
  static const unfavExtra = 'Доп. услуга убрана из избранного';
  static const updateProfile = 'Обновление профиля';
}

class LogService {
  static final LogService _instance = LogService._();
  static LogService get instance => _instance;
  LogService._();

  final _api = ApiService();

  Future<void> log(String username, String action, String details) async {
    try {
      await _api.createLog(username.toLowerCase(), action, details);
    } catch (e) {
      debugPrint('[LogService] Ошибка записи лога: $e');
    }
  }

  Future<List<LogEntry>> getAll({int limit = 200}) =>
      _api.getLogs(limit: limit);
  Future<List<LogEntry>> getByUser(String username) =>
      _api.getLogsByUser(username);
  Future<void> clearAll() => _api.clearLogs();
}
