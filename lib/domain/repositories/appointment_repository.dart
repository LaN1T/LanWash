import '../entities/appointment.dart';

abstract class AppointmentRepository {
  Future<List<Appointment>> getAppointments();
  Future<Appointment?> getAppointmentById(String id);
  Future<List<Appointment>> getAppointmentsByOwner(String username);
  Future<List<Appointment>> getAppointmentsByWasher(String username);
  Future<bool> createAppointment(Appointment appointment);
  Future<bool> updateAppointment(Appointment appointment);
  Future<bool> deleteAppointment(String id);
  Future<void> toggleAppointmentFavorite(String id);
  Future<void> markAppointmentSeen(String id);
}
