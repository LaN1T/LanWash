import 'package:flutter/material.dart';
import '../services/api_service.dart';

class FavoriteProvider extends ChangeNotifier {
  final ApiService _api;

  FavoriteProvider({required ApiService api}) : _api = api;

  Set<String> _extraFavSet = {};
  Set<String> _serviceFavSet = {};
  String _currentUser = '';

  Set<String> get extraFavorites => _extraFavSet;
  Set<String> get serviceFavorites => _serviceFavSet;
  bool isExtraFavorite(String serviceId) => _extraFavSet.contains(serviceId);
  bool isServiceFavorite(String id) => _serviceFavSet.contains(id);

  Future<void> loadForUser(String username) async {
    _currentUser = username.toLowerCase();
    try {
      _extraFavSet = await _api.getExtraFavorites(_currentUser);
      _serviceFavSet = await _api.getServiceFavorites(_currentUser);
      notifyListeners();
    } catch (e) {}
  }

  Future<void> clearData() async {
    _extraFavSet = {};
    _serviceFavSet = {};
    _currentUser = '';
    notifyListeners();
  }

  Future<void> toggleServiceFavorite(String id) async {
    final user = _currentUser.isNotEmpty ? _currentUser : 'admin';
    try {
      final ok = await _api.toggleServiceFavorite(user, id);
      if (ok) {
        if (_serviceFavSet.contains(id)) {
          _serviceFavSet.remove(id);
        } else {
          _serviceFavSet.add(id);
        }
        notifyListeners();
      }
    } catch (e) {}
  }

  Future<void> toggleExtraFavorite(String serviceId) async {
    final user = _currentUser.isNotEmpty ? _currentUser : 'admin';
    try {
      final ok = await _api.toggleExtraFavorite(user, serviceId);
      if (ok) {
        if (_extraFavSet.contains(serviceId)) {
          _extraFavSet.remove(serviceId);
        } else {
          _extraFavSet.add(serviceId);
        }
        notifyListeners();
      }
    } catch (e) {}
  }
}
