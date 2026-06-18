import 'package:flutter/material.dart';
import '../models/service.dart';
import '../models/promo.dart';
import '../models/wash_type.dart';
import '../services/api_service.dart';

class CatalogProvider extends ChangeNotifier {
  final ApiService _api;

  CatalogProvider({required ApiService api}) : _api = api;

  List<Service> _serviceList = [];
  List<Promo> _promoList = [];
  List<WashType> _washTypeList = [];
  String? _errorMessage;

  List<Service> get services => _serviceList;
  List<Promo> get promos => _promoList;
  List<WashType> get washTypes => _washTypeList;
  String? get errorMessage => _errorMessage;

  void clearError() => _errorMessage = null;

  WashType? washTypeById(String id) {
    final results = _washTypeList.where((w) => w.id == id);
    return results.isNotEmpty ? results.first : null;
  }

  WashType? washTypeByCode(String code) {
    final results = _washTypeList.where((w) => w.code == code);
    return results.isNotEmpty ? results.first : null;
  }

  String washTypeName(String id) => washTypeById(id)?.name ?? id;

  Promo? promoById(String id) {
    final results = _promoList.where((p) => p.id == id);
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> load() async {
    clearError();
    try {
      final results = await Future.wait([
        _api.getServices(),
        _api.getPromos(),
        _api.getWashTypes(),
      ]);
      _serviceList = results[0] as List<Service>;
      _promoList = results[1] as List<Promo>;
      _washTypeList = results[2] as List<WashType>;
    } catch (e) {
      _errorMessage = 'Ошибка загрузки данных. Проверьте подключение.';
    }
    notifyListeners();
  }

  Future<void> reloadServices() async {
    clearError();
    try {
      _serviceList = await _api.getServices();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Ошибка загрузки услуг';
      notifyListeners();
    }
  }

  Future<void> reloadPromos() async {
    clearError();
    try {
      _promoList = await _api.getPromos();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Ошибка загрузки акций';
      notifyListeners();
    }
  }

  Future<void> reloadWashTypes() async {
    clearError();
    try {
      _washTypeList = await _api.getWashTypes();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Ошибка загрузки типов мойки';
      notifyListeners();
    }
  }

  Future<bool> addService(Service s) async {
    clearError();
    try {
      await _api.createService(s);
      _serviceList = await _api.getServices();
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Ошибка добавления услуги';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateService(Service s) async {
    clearError();
    try {
      await _api.updateService(s);
      final i = _serviceList.indexWhere((x) => x.id == s.id);
      if (i != -1) _serviceList[i] = s;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Ошибка обновления услуги';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteService(String id) async {
    clearError();
    try {
      await _api.deleteService(id);
      _serviceList.removeWhere((s) => s.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Ошибка удаления услуги';
      notifyListeners();
      return false;
    }
  }

  Future<List<String>> getServiceCategories() => _api.getServiceCategories();

  Future<bool> updateWashType(WashType wt) async {
    final updated = await _api.updateWashType(wt);
    if (updated != null) {
      final i = _washTypeList.indexWhere((x) => x.id == updated.id);
      if (i != -1) {
        _washTypeList[i] = updated;
      } else {
        _washTypeList.add(updated);
      }
      _washTypeList.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      notifyListeners();
      return true;
    }
    return false;
  }
}
