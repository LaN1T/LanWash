import '../../domain/entities/service.dart';
import '../../domain/repositories/service_repository.dart';
import '../datasources/remote/service_api.dart';

class ServiceRepositoryImpl implements ServiceRepository {
  final ServiceApi remoteDataSource;

  ServiceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Service>> getServices() async {
    return await remoteDataSource.getServices();
  }

  @override
  Future<bool> createService(Service service) async {
    return await remoteDataSource.createService(service);
  }

  @override
  Future<bool> updateService(Service service) async {
    return await remoteDataSource.updateService(service);
  }

  @override
  Future<bool> deleteService(String id) async {
    return await remoteDataSource.deleteService(id);
  }
}
