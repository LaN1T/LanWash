import '../../../core/usecases/usecase.dart';
import '../../entities/service.dart';
import '../../repositories/service_repository.dart';

class GetServices implements UseCase<List<Service>, NoParams> {
  final ServiceRepository repository;

  GetServices(this.repository);

  @override
  Future<List<Service>> call(NoParams params) async {
    return await repository.getServices();
  }
}
