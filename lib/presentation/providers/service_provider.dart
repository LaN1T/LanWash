import 'package:flutter/material.dart';
import '../../domain/entities/service.dart';
import '../../domain/repositories/service_repository.dart';
import '../../domain/usecases/service/get_services.dart';
import '../../core/usecases/usecase.dart';

class ServiceProvider extends ChangeNotifier {
  final GetServices _getServices;
  final ServiceRepository _repository;

  List<Service> _services = [];
  bool _loading = false;

  ServiceProvider({required ServiceRepository repository})
      : _repository = repository,
        _getServices = GetServices(repository);

  List<Service> get services => _services;
  bool get loading => _loading;

  Future<void> loadServices() async {
    _loading = true;
    notifyListeners();
    _services = await _getServices(NoParams());
    _loading = false;
    notifyListeners();
  }

  Future<bool> createService(Service service) async {
    final success = await _repository.createService(service);
    if (success) await loadServices();
    return success;
  }

  Future<bool> updateService(Service service) async {
    final success = await _repository.updateService(service);
    if (success) await loadServices();
    return success;
  }

  Future<bool> deleteService(String id) async {
    final success = await _repository.deleteService(id);
    if (success) await loadServices();
    return success;
  }
}
