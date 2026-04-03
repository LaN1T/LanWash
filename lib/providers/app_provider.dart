import 'package:flutter/material.dart';
import '../models/appointment.dart';
import '../models/service.dart';
import '../repositories/appointment_repository.dart';
import '../repositories/service_repository.dart';
import '../repositories/extra_favorites_repository.dart';
import '../repositories/service_favorites_repository.dart';
import '../services/api_service.dart';
import '../services/log_service.dart';

class AppProvider extends ChangeNotifier {
  final _appointments   = AppointmentRepository();
  final _services       = ServiceRepository();
  final _api            = ApiService();
  final _extraFavs      = ExtraFavoritesRepository();
  final _serviceFavs    = ServiceFavoritesRepository();

  List<Appointment> _appointmentList = [];
  List<Service>     _serviceList     = [];
  Set<String>       _extraFavSet     = {};
  Set<String>       _serviceFavSet   = {}; // id услуг в избранном текущего юзера
  String            _currentUser     = '';
  bool _loading    = true;
  bool _loadingApi = false;

  List<Appointment> get appointments   => _appointmentList;
  List<Service>     get services       => _serviceList;
  Set<String>       get extraFavorites => _extraFavSet;
  bool              get loading        => _loading;
  bool              get loadingApi     => _loadingApi;

  List<Appointment> get favoriteAppointments =>
      _appointmentList.where((a) => a.isFavorite).toList();

  /// Избранные услуги каталога текущего пользователя
  List<Service> get favoriteServices =>
      _serviceList.where((s) => _serviceFavSet.contains(s.id)).toList();

  bool isServiceFavorite(String id) => _serviceFavSet.contains(id);

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    _appointmentList = await _appointments.getAll();
    _serviceList     = await _services.getAll();
    _loading         = false;
    notifyListeners();

    _fetchPromos();
  }

  Future<void> reloadAppointments() async {
    _appointmentList = await _appointments.getAll();
    notifyListeners();
  }

  Future<void> reloadForUser(String username) async {
    _currentUser     = username.toLowerCase();
    _appointmentList = await _appointments.getByOwner(_currentUser);
    _extraFavSet     = await _extraFavs.getForUser(_currentUser);
    _serviceFavSet   = await _serviceFavs.getForUser(_currentUser);
    notifyListeners();
  }

  /// Сброс при выходе из аккаунта
  Future<void> clearData() async {
    _appointmentList = [];
    _extraFavSet     = {};
    _serviceFavSet   = {};
    _currentUser     = '';
    notifyListeners();
  }

  Future<void> _fetchPromos() async {
    _loadingApi = true;
    notifyListeners();

    final promos = await _api.fetchPromoServices();
    if (promos.isNotEmpty) {
      await _services.replacePromos(promos);
      _serviceList = await _services.getAll();
    }

    _loadingApi = false;
    notifyListeners();
  }

  // ─── Записи ──────────────────────────────────────────────────────────────
  Future<void> addAppointment(Appointment a) async {
    await _appointments.insert(a);
    if (_currentUser.isNotEmpty) {
      _appointmentList = await _appointments.getByOwner(_currentUser);
    } else {
      _appointmentList = await _appointments.getAll();
    }
    notifyListeners();
    await LogService.instance.log(_currentUser, LogAction.createAppt,
        '${a.washType.displayName} · ${a.carModel} ${a.carNumber} · ${a.totalPrice}₽');
  }

  Future<void> updateAppointment(Appointment a) async {
    await _appointments.update(a);
    final i = _appointmentList.indexWhere((x) => x.id == a.id);
    if (i != -1) _appointmentList[i] = a;
    notifyListeners();
    await LogService.instance.log(_currentUser.isNotEmpty ? _currentUser : 'admin',
        LogAction.editAppt,
        '${a.washType.displayName} · ${a.carModel} · статус: ${a.status}');
  }

  Future<void> deleteAppointment(String id) async {
    final appt = _appointmentList.firstWhere((a) => a.id == id,
        orElse: () => _appointmentList.first);
    await _appointments.delete(id);
    _appointmentList.removeWhere((a) => a.id == id);
    notifyListeners();
    await LogService.instance.log(_currentUser.isNotEmpty ? _currentUser : 'admin',
        LogAction.deleteAppt,
        '${appt.washType.displayName} · ${appt.carModel} ${appt.carNumber}');
  }

  Future<void> toggleAppointmentFavorite(String id) async {
    await _appointments.toggleFavorite(id);
    final i = _appointmentList.indexWhere((a) => a.id == id);
    if (i != -1) {
      _appointmentList[i] = _appointmentList[i].copyWith(
          isFavorite: !_appointmentList[i].isFavorite);
      notifyListeners();
    }
  }

  Future<Map<String, int>> getStats() => _appointments.getStats();

  // ─── Услуги ──────────────────────────────────────────────────────────────
  Future<void> addService(Service s) async {
    await _services.insert(s);
    _serviceList = await _services.getAll();
    notifyListeners();
  }

  Future<void> updateService(Service s) async {
    await _services.update(s);
    final i = _serviceList.indexWhere((x) => x.id == s.id);
    if (i != -1) _serviceList[i] = s;
    notifyListeners();
  }

  Future<void> deleteService(String id) async {
    await _services.delete(id);
    _serviceList.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  Future<void> toggleServiceFavorite(String id) async {
    if (_currentUser.isEmpty) return;
    final wasFav = _serviceFavSet.contains(id);
    await _serviceFavs.toggle(_currentUser, id);
    if (wasFav) {
      _serviceFavSet.remove(id);
    } else {
      _serviceFavSet.add(id);
    }
    notifyListeners();
    final svc = _serviceList.firstWhere((s) => s.id == id,
        orElse: () => _serviceList.first);
    await LogService.instance.log(_currentUser,
        wasFav ? LogAction.unfavService : LogAction.favService, svc.name);
  }

  Future<List<String>> getServiceCategories() =>
      _services.getCategories();

  // ─── Избранные доп. услуги (для клиента) ─────────────────────────────────
  Future<void> toggleExtraFavorite(String serviceName) async {
    if (_currentUser.isEmpty) return;
    final wasFav = _extraFavSet.contains(serviceName);
    await _extraFavs.toggle(_currentUser, serviceName);
    if (wasFav) {
      _extraFavSet.remove(serviceName);
    } else {
      _extraFavSet.add(serviceName);
    }
    notifyListeners();
    await LogService.instance.log(_currentUser,
        wasFav ? LogAction.unfavExtra : LogAction.favExtra, serviceName);
  }

  bool isExtraFavorite(String serviceName) =>
      _extraFavSet.contains(serviceName);
}
