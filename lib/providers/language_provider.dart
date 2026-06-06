import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_strings.dart';

enum AppLanguage { ru, en }

class LanguageProvider extends ChangeNotifier {
  static const _key = 'app_language';

  AppLanguage _language = AppLanguage.ru;

  AppLanguage get language => _language;
  Locale get locale {
    switch (_language) {
      case AppLanguage.ru:
        return const Locale('ru', 'RU');
      case AppLanguage.en:
        return const Locale('en', 'US');
    }
  }

  String get langCode => _language.name;

  LanguageProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _language = AppLanguage.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => AppLanguage.ru,
    );
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage lang) async {
    _language = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.name);
    notifyListeners();
  }

  void toggle() {
    final next = _language == AppLanguage.ru ? AppLanguage.en : AppLanguage.ru;
    setLanguage(next);
  }

  String tr(String key) => AppStrings.of(key, langCode);
}
