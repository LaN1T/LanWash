import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/appointment.dart';
import '../../models/service.dart';
import '../../models/wash_type.dart';
import '../../providers/app_provider.dart';

mixin AppointmentFormLogic {
  bool isSlotAvailable(BuildContext context, DateTime dt, int duration, {Appointment? currentAppointment}) {
    final busy = context.read<AppProvider>().busySlots['busy_slots'] as List;
    final start = dt;
    final end = dt.add(Duration(minutes: duration));

    for (int boxIdx = 0; boxIdx < busy.length; boxIdx++) {
      bool isBoxFree = true;
      for (final slot in busy[boxIdx]) {
        final slotStart = DateTime.parse(slot['start']);
        final slotEnd = DateTime.parse(slot['end']);
        if (currentAppointment != null) {
          final provider = context.read<AppProvider>();
          final origStart = currentAppointment.dateTime;
          final wt = provider.washTypeById(currentAppointment.washTypeId);
          int origDuration = wt?.durationMinutes ?? 30;
          for (final id in currentAppointment.additionalServices) {
            final svc = provider.services.firstWhere((s) => s.id == id,
                orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: ''));
            origDuration += svc.durationMinutes;
          }
          final origEnd = origStart.add(Duration(minutes: origDuration));
          if (slotStart.isAtSameMomentAs(origStart) && slotEnd.isAtSameMomentAs(origEnd)) continue;
        }
        if (start.isBefore(slotEnd) && end.isAfter(slotStart)) {
          isBoxFree = false;
          break;
        }
      }
      if (isBoxFree) return true;
    }
    return false;
  }

  Future<int> getDuration(AppProvider provider, String washTypeId, Set<String> selectedAddServices) async {
    final wt = provider.washTypeById(washTypeId);
    int duration = wt?.durationMinutes ?? 30;
    for (final id in selectedAddServices) {
      final svc = provider.services.firstWhere((s) => s.id == id, 
          orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: ''));
      duration += svc.durationMinutes;
    }
    return duration;
  }

  int calcPrice(AppProvider provider, String washTypeId, Set<String> selectedAddServices, String? selectedPromoId) {
    final wt = provider.washTypeById(washTypeId);
    final promo = selectedPromoId == null ? null : provider.promoById(selectedPromoId);
    final locked = <String>{...?wt?.includedExtraIds, ...?promo?.includedExtraIds};
    int base = promo != null ? (promo.discountPercent > 0 ? (wt?.basePrice ?? 0) * (100 - promo.discountPercent) ~/ 100 : promo.price) : (wt?.basePrice ?? 0);
    int p = base;
    for (final id in selectedAddServices) {
      if (locked.contains(id)) continue;
      final svc = provider.services.firstWhere((s) => s.id == id, orElse: () => Service(id: id, name: id, description: '', price: 0, durationMinutes: 0, category: ''));
      p += svc.price;
    }
    return p;
  }
}