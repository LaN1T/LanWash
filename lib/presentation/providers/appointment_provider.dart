import 'package:flutter/material.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/repositories/appointment_repository.dart';
import '../../domain/usecases/appointment/create_appointment.dart';
import '../../domain/usecases/appointment/get_appointments.dart';
import '../../domain/usecases/appointment/cancel_appointment.dart';
import '../../core/usecases/usecase.dart';

class AppointmentProvider extends ChangeNotifier {
  final CreateAppointment _createAppointment;
  final GetAppointments _getAppointments;
  final CancelAppointment _cancelAppointment;

  List<Appointment> _appointments = [];
  bool _loading = false;

  AppointmentProvider({
    required AppointmentRepository repository,
  })  : _createAppointment = CreateAppointment(repository),
        _getAppointments = GetAppointments(repository),
        _cancelAppointment = CancelAppointment(repository);

  List<Appointment> get appointments => _appointments;
  bool get loading => _loading;

  Future<void> loadAppointments() async {
    _loading = true;
    notifyListeners();
    
    final result = await _getAppointments(NoParams());
    _appointments = result;
    
    _loading = false;
    notifyListeners();
  }

  Future<bool> create(Appointment appointment) async {
    final success = await _createAppointment(appointment);
    if (success) {
      await loadAppointments();
    }
    return success;
  }

  Future<bool> cancel(String id) async {
    final success = await _cancelAppointment(id);
    if (success) {
      await loadAppointments();
    }
    return success;
  }
}
