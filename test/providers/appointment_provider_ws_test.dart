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
  test('applyWebSocketAppointment replaces existing appointment', () async {
    final api = MockApiService();
    final notifications = MockNotificationService();
    final auth = MockAuthProvider();
    when(() => auth.isAdmin).thenReturn(false);
    when(() => notifications.onAppointmentUpdated)
        .thenAnswer((_) => StreamController<String>.broadcast().stream);

    final provider = AppointmentProvider(
      api: api,
      notificationService: notifications,
    );
    provider.appointments.add(_dummyAppointment('a1'));

    await provider.applyWebSocketAppointment({
      'id': 'a1',
      'clientName': 'New Name',
      'carModel': 'Kia',
      'carNumber': 'A111AA77',
      'dateTime': DateTime.now().toIso8601String(),
      'washTypeId': 'w1',
      'additionalServices': [],
      'status': 'in_progress',
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
    }, 'updated', auth);

    expect(provider.appointments.first.status, 'in_progress');
    expect(provider.appointments.first.clientName, 'New Name');
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
