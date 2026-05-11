import '../entities/service.dart';

abstract class ServiceRepository {
  Future<List<Service>> getServices();
  Future<bool> createService(Service service);
  Future<bool> updateService(Service service);
  Future<bool> deleteService(String id);
}
