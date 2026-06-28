import 'package:flutter/foundation.dart';
import '../models/consumable.dart';
import '../models/consumable_history_item.dart';
import '../services/api_service.dart';

/// Provider for the consumables list and related admin operations.
///
/// Used to compute the low-stock badge in admin UI and to share the
/// consumables list between settings and stock-management screens.
class ConsumableProvider extends ChangeNotifier {
  final ApiService _api;

  ConsumableProvider({required ApiService api}) : _api = api;

  List<Consumable> _items = [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Consumable> get items => _items;
  bool get loading => _loading;
  bool get loaded => _loaded;
  String? get error => _error;

  int get lowStockCount => _items.where((c) => c.isLowStock).length;
  bool get hasLowStock => lowStockCount > 0;

  Future<void> load() async {
    if (_loaded) return;
    await refresh();
  }

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();

    try {
      _items = await _api.getConsumables();
      _loaded = true;
      _error = null;
    } catch (e) {
      _error = e.toString();
      if (kDebugMode) debugPrint('ConsumableProvider load error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<List<ConsumableHistoryItem>> getHistory(
    String consumableId,
    String type,
  ) async {
    return _api.getConsumableHistory(consumableId, type: type);
  }
}
