import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../datasources/remote/appointment_api.dart';

class AppointmentRepositoryImpl implements AppointmentRepository {
  final AppointmentApi remoteDataSource;

  AppointmentRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Appointment?> getAppointmentById(String id) async {
    // Assuming we fetch all and find, or we add getAppointmentById to AppointmentApi
    final all = await remoteDataSource.getAppointments();
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Appointment>> getAppointmentsByOwner(String username) async {
    return await remoteDataSource.getAppointmentsByOwner(username);
  }

  @override
  Future<List<Appointment>> getAppointmentsByWasher(String username) async {
    return await remoteDataSource.getAppointmentsByWasher(username);
  }

  @override
  Future<bool> createAppointment(Appointment appointment) async {
    return await remoteDataSource.createAppointment(appointment);
  }

  @override
  Future<bool> updateAppointment(Appointment appointment) async {
    return await remoteDataSource.updateAppointment(appointment);
  }

  @override
  Future<bool> deleteAppointment(String id) async {
    return await remoteDataSource.deleteAppointment(id);
  }

  @override
  Future<void> toggleAppointmentFavorite(String id) async {
    return await remoteDataSource.toggleAppointmentFavorite(id);
  }

  @override
  Future<void> markAppointmentSeen(String id) async {
    return await remoteDataSource.markAppointmentSeen(id);
  }
}
