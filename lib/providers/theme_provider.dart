import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier {
  static const _key = 'app_theme_mode';

  ThemeMode _themeMode = ThemeMode.system;
  AppThemeMode _appThemeMode = AppThemeMode.system;

  ThemeMode get themeMode => _themeMode;
  AppThemeMode get appThemeMode => _appThemeMode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _appThemeMode = AppThemeMode.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppThemeMode.system,
    );
    _syncThemeMode();
    notifyListeners();
  }

  Future<void> setMode(AppThemeMode mode) async {
    _appThemeMode = mode;
    _syncThemeMode();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
    notifyListeners();
  }

  void _syncThemeMode() {
    switch (_appThemeMode) {
      case AppThemeMode.light:
        _themeMode = ThemeMode.light;
      case AppThemeMode.dark:
        _themeMode = ThemeMode.dark;
      case AppThemeMode.system:
        _themeMode = ThemeMode.system;
    }
  }
}
