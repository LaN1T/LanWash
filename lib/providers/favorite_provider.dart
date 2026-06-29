import 'package:flutter/foundation.dart';
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
    } catch (e) {
      debugPrint('FavoriteProvider.loadForUser error: $e');
    }
  }

  Future<void> clearData() async {
    _extraFavSet = {};
    _serviceFavSet = {};
    _currentUser = '';
    notifyListeners();
  }

  Future<void> toggleServiceFavorite(String id) async {
    if (_currentUser.isEmpty) {
      debugPrint(
          'FavoriteProvider: cannot toggle favorite with no user loaded');
      return;
    }
    try {
      final ok = await _api.toggleServiceFavorite(_currentUser, id);
      if (ok) {
        if (_serviceFavSet.contains(id)) {
          _serviceFavSet.remove(id);
        } else {
          _serviceFavSet.add(id);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('FavoriteProvider.toggleServiceFavorite error: $e');
    }
  }

  Future<void> toggleExtraFavorite(String serviceId) async {
    if (_currentUser.isEmpty) {
      debugPrint(
          'FavoriteProvider: cannot toggle favorite with no user loaded');
      return;
    }
    try {
      final ok = await _api.toggleExtraFavorite(_currentUser, serviceId);
      if (ok) {
        if (_extraFavSet.contains(serviceId)) {
          _extraFavSet.remove(serviceId);
        } else {
          _extraFavSet.add(serviceId);
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('FavoriteProvider.toggleExtraFavorite error: $e');
    }
  }
}
