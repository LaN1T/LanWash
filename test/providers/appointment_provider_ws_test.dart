import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lanwash/models/appointment.dart';
import 'package:lanwash/providers/appointment_provider.dart';
import 'package:lanwash/providers/auth_provider.dart';
import 'package:lanwash/services/api_service.dart';
import 'package:lanwash/services/notification_service.dart';
import 'package:mocktail/mocktail.dart';

class MockApiService extends Mock implements ApiService {}

class MockNotificationService extends Mock implements NotificationService {}

class MockAuthProvider extends Mock implements AuthProvider {}

void main() {
  group('applyWebSocketAppointment', () {
    late MockApiService api;
    late MockNotificationService notifications;
    late MockAuthProvider auth;
    late StreamController<String> notifController;
    late AppointmentProvider provider;

    setUp(() {
      api = MockApiService();
      notifications = MockNotificationService();
      auth = MockAuthProvider();
      notifController = StreamController<String>.broadcast();

      when(() => notifications.onAppointmentUpdated)
          .thenAnswer((_) => notifController.stream);
      when(() => auth.isAdmin).thenReturn(false);

      provider = AppointmentProvider(
        api: api,
        notificationService: notifications,
      );
    });

    tearDown(() {
      provider.dispose();
      notifController.close();
    });

    test('replaces existing appointment', () async {
      provider.appointments.add(_dummyAppointment('a1'));

      await provider.applyWebSocketAppointment(
        _appointmentMap(id: 'a1', status: 'in_progress', clientName: 'New Name'),
        'updated',
        auth,
      );

      expect(provider.appointments.first.status, 'in_progress');
      expect(provider.appointments.first.clientName, 'New Name');
    });

    test('deleted event removes the appointment', () async {
      provider.appointments.add(_dummyAppointment('a1'));
      provider.appointments.add(_dummyAppointment('a2'));

      await provider.applyWebSocketAppointment(
        _appointmentMap(id: 'a1'),
        'deleted',
        auth,
      );

      expect(provider.appointments.length, 1);
      expect(provider.appointments.first.id, 'a2');
    });

    test('unknown appointment for non-admin inserts at index 0', () async {
      provider.appointments.add(_dummyAppointment('old'));

      await provider.applyWebSocketAppointment(
        _appointmentMap(id: 'new', status: 'completed', clientName: 'Inserted'),
        'updated',
        auth,
      );

      expect(provider.appointments.length, 2);
      expect(provider.appointments.first.id, 'new');
      expect(provider.appointments.first.status, 'completed');
      expect(provider.appointments.first.clientName, 'Inserted');
    });

    test('unknown appointment for admin triggers reloadAppointments', () async {
      when(() => auth.isAdmin).thenReturn(true);
      provider.appointments.add(_dummyAppointment('old'));

      final newAppointment = _dummyAppointment('new');
      when(
        () => api.getAppointments(
          page: any(named: 'page'),
          date: any(named: 'date'),
        ),
      ).thenAnswer(
        (_) async => PaginatedAppointments(
          appointments: [newAppointment],
          totalPages: 1,
          currentPage: 1,
          currentDate: '',
          uniqueDates: const [],
        ),
      );

      await provider.applyWebSocketAppointment(
        _appointmentMap(id: 'new'),
        'updated',
        auth,
      );

      expect(provider.appointments.length, 1);
      expect(provider.appointments.first.id, 'new');
      verify(
        () => api.getAppointments(
          page: any(named: 'page'),
          date: any(named: 'date'),
        ),
      ).called(1);
    });

    test('invalid payload falls back to emitting update', () async {
      const id = 'bad-id';

      await provider.applyWebSocketAppointment(
        {'id': id, 'carId': 'not-a-number'},
        'updated',
        auth,
      );

      expect(provider.errorMessage, 'Ошибка обновления записи');
      verify(() => notifications.emitAppointmentUpdated(id)).called(1);
    });
  });
}

Appointment _dummyAppointment(String id) => Appointment(
      id: id,
      clientName: 'Old',
      carModel: 'Lada',
      carNumber: 'A000AA77',
      dateTime: DateTime.now(),
      washTypeId: 'w1',
      additionalServices: const [],
      status: 'scheduled',
      notes: '',
      ownerUsername: 'client',
    );

Map<String, dynamic> _appointmentMap({
  required String id,
  String status = 'scheduled',
  String clientName = 'New',
}) =>
    {
      'id': id,
      'clientName': clientName,
      'carModel': 'Kia',
      'carNumber': 'A111AA77',
      'dateTime': DateTime.now().toIso8601String(),
      'washTypeId': 'w1',
      'additionalServices': [],
      'status': status,
      'notes': '',
      'isFavorite': false,
      'ownerUsername': 'client',
      'promoPrice': 0,
      'paidPrice': 0,
      'originalPrice': 0,
      'isModifiedByAdmin': false,
      'isModifiedByWasher': false,
      'isSeenByClient': true,
      'assignedWasher': [],
      'promoId': null,
      'box_index': 0,
      'late_minutes': 0,
      'cancel_reason': '',
    };
