import 'dart:async';
import 'package:flutter/material.dart';
import '../../domain/entities/appointment.dart';
import '../../domain/entities/service.dart';
import '../../domain/entities/promo.dart';
import '../../domain/entities/note.dart';
import '../../domain/entities/wash_type.dart';
import '../../domain/repositories/appointment_repository.dart';
import 'auth_provider.dart';

class AppProvider extends ChangeNotifier {
  final AppointmentRepository _appointmentRepo;
  
  List<Appointment> _appointments = [];
  bool _loading = false;

  AppProvider({required AppointmentRepository appointmentRepository})
      : _appointmentRepo = appointmentRepository;

  List<Appointment> get appointments => _appointments;
  bool get loading => _loading;

  Future<void> init(AuthProvider auth) async {
    _loading = true;
    notifyListeners();
    _appointments = await _appointmentRepo.getAppointments();
    _loading = false;
    notifyListeners();
  }
}
