import '../../../core/usecases/usecase.dart';
import '../../repositories/appointment_repository.dart';

class CancelAppointment implements UseCase<bool, String> {
  final AppointmentRepository repository;

  CancelAppointment(this.repository);

  @override
  Future<bool> call(String id) async {
    final appointment = await repository.getAppointmentById(id);
    if (appointment == null) return false;

    final updated = appointment.copyWith(status: 'cancelled'); // Note: Appointment entity needs copyWith
    return await repository.updateAppointment(updated);
  }
}
