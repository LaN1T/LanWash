import '../../../core/usecases/usecase.dart';
import '../../entities/appointment.dart';
import '../../repositories/appointment_repository.dart';

class CreateAppointment implements UseCase<bool, Appointment> {
  final AppointmentRepository repository;

  CreateAppointment(this.repository);

  @override
  Future<bool> call(Appointment appointment) async {
    return await repository.createAppointment(appointment);
  }
}
