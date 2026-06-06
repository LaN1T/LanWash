import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/services/car_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', (message) async {
      const json = '[{"brand":"Toyota","models":["Camry","Corolla"]}]';
      final bytes = Uint8List.fromList(utf8.encode(json));
      return ByteData.sublistView(bytes);
    });
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('flutter/assets', null);
  });

  test('load and search brands', () async {
    final svc = CarCatalogService();
    await svc.load();
    expect(svc.searchBrands('to'), ['Toyota']);
    expect(svc.searchBrands('xx'), isEmpty);
    expect(svc.allBrandNames, ['Toyota']);
  });

  test('search models by brand', () async {
    final svc = CarCatalogService();
    await svc.load();
    expect(svc.searchModels('Toyota', 'ca'), ['Camry']);
    expect(svc.searchModels('Toyota', 'xx'), isEmpty);
    expect(svc.modelsForBrand('Toyota'), ['Camry', 'Corolla']);
  });
}
