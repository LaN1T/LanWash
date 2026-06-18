import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class CarBrand {
  final String name;
  final List<String> models;

  const CarBrand({required this.name, required this.models});

  factory CarBrand.fromJson(Map<String, dynamic> json) {
    return CarBrand(
      name: json['brand'] as String,
      models: (json['models'] as List<dynamic>).cast<String>(),
    );
  }
}

List<CarBrand> _parseCatalog(String raw) {
  final list = jsonDecode(raw) as List<dynamic>;
  return list.map((e) => CarBrand.fromJson(e as Map<String, dynamic>)).toList();
}

class CarCatalogService {
  List<CarBrand>? _brands;
  List<String>? _allBrandNames;
  final Map<String, List<String>> _modelsByBrand = {};

  Future<void> load() async {
    if (_brands != null) return;
    final raw = await rootBundle.loadString('assets/data/car_catalog.json');
    final brands = await compute(_parseCatalog, raw);
    _brands = brands;
    _allBrandNames = brands.map((b) => b.name).toList();
    for (final brand in brands) {
      _modelsByBrand[brand.name] = brand.models;
    }
  }

  List<String> searchBrands(String query) {
    if (_allBrandNames == null) return [];
    final q = query.toLowerCase();
    return _allBrandNames!.where((b) => b.toLowerCase().startsWith(q)).toList();
  }

  List<String> searchModels(String brand, String query) {
    final models = _modelsByBrand[brand];
    if (models == null) return [];
    final q = query.toLowerCase();
    return models.where((m) => m.toLowerCase().startsWith(q)).toList();
  }

  List<String> get allBrandNames => _allBrandNames ?? [];
  List<String> modelsForBrand(String brand) => _modelsByBrand[brand] ?? [];
}
