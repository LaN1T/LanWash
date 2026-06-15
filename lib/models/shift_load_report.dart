class ShiftLoadReport {
  final String startDate;
  final String endDate;
  final int targetWeeklyMinutesPerWasher;
  final List<ShiftLoadDailyEntry> dailyHours;
  final List<ShiftLoadWasherStat> washerStats;
  final ShiftLoadStatusCounts statusCounts;
  final int conflictCount;
  final ShiftLoadAvailabilityCoverage availabilityCoverage;

  const ShiftLoadReport({
    required this.startDate,
    required this.endDate,
    required this.targetWeeklyMinutesPerWasher,
    required this.dailyHours,
    required this.washerStats,
    required this.statusCounts,
    required this.conflictCount,
    required this.availabilityCoverage,
  });

  factory ShiftLoadReport.fromMap(Map<String, dynamic> map) {
    return ShiftLoadReport(
      startDate: map['startDate'] as String,
      endDate: map['endDate'] as String,
      targetWeeklyMinutesPerWasher:
          map['targetWeeklyMinutesPerWasher'] as int? ?? 2400,
      dailyHours: ((map['dailyHours'] ?? []) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ShiftLoadDailyEntry.fromMap)
          .toList(),
      washerStats: ((map['washerStats'] ?? []) as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(ShiftLoadWasherStat.fromMap)
          .toList(),
      statusCounts:
          ShiftLoadStatusCounts.fromMap(map['statusCounts'] as Map<String, dynamic>),
      conflictCount: map['conflictCount'] as int? ?? 0,
      availabilityCoverage: ShiftLoadAvailabilityCoverage.fromMap(
          map['availabilityCoverage'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toMap() => {
        'startDate': startDate,
        'endDate': endDate,
        'targetWeeklyMinutesPerWasher': targetWeeklyMinutesPerWasher,
        'dailyHours': dailyHours.map((e) => e.toMap()).toList(),
        'washerStats': washerStats.map((e) => e.toMap()).toList(),
        'statusCounts': statusCounts.toMap(),
        'conflictCount': conflictCount,
        'availabilityCoverage': availabilityCoverage.toMap(),
      };
}

class ShiftLoadDailyEntry {
  final String date;
  final int confirmedMinutes;
  final int pendingMinutes;

  const ShiftLoadDailyEntry({
    required this.date,
    required this.confirmedMinutes,
    required this.pendingMinutes,
  });

  factory ShiftLoadDailyEntry.fromMap(Map<String, dynamic> map) {
    return ShiftLoadDailyEntry(
      date: map['date'] as String,
      confirmedMinutes: map['confirmedMinutes'] as int? ?? 0,
      pendingMinutes: map['pendingMinutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'confirmedMinutes': confirmedMinutes,
        'pendingMinutes': pendingMinutes,
      };
}

class ShiftLoadWasherStat {
  final int userId;
  final String displayName;
  final int confirmedMinutes;
  final int pendingMinutes;
  final int rejectedMinutes;
  final double utilizationPercent;
  final bool isOvertime;
  final bool isUnderload;

  const ShiftLoadWasherStat({
    required this.userId,
    required this.displayName,
    required this.confirmedMinutes,
    required this.pendingMinutes,
    required this.rejectedMinutes,
    required this.utilizationPercent,
    required this.isOvertime,
    required this.isUnderload,
  });

  factory ShiftLoadWasherStat.fromMap(Map<String, dynamic> map) {
    return ShiftLoadWasherStat(
      userId: map['userId'] as int,
      displayName: map['displayName'] as String,
      confirmedMinutes: map['confirmedMinutes'] as int? ?? 0,
      pendingMinutes: map['pendingMinutes'] as int? ?? 0,
      rejectedMinutes: map['rejectedMinutes'] as int? ?? 0,
      utilizationPercent: (map['utilizationPercent'] as num?)?.toDouble() ?? 0.0,
      isOvertime: map['isOvertime'] as bool? ?? false,
      isUnderload: map['isUnderload'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'displayName': displayName,
        'confirmedMinutes': confirmedMinutes,
        'pendingMinutes': pendingMinutes,
        'rejectedMinutes': rejectedMinutes,
        'utilizationPercent': utilizationPercent,
        'isOvertime': isOvertime,
        'isUnderload': isUnderload,
      };
}

class ShiftLoadStatusCounts {
  final int confirmed;
  final int pending;
  final int rejected;

  const ShiftLoadStatusCounts({
    required this.confirmed,
    required this.pending,
    required this.rejected,
  });

  factory ShiftLoadStatusCounts.fromMap(Map<String, dynamic> map) {
    return ShiftLoadStatusCounts(
      confirmed: map['confirmed'] as int? ?? 0,
      pending: map['pending'] as int? ?? 0,
      rejected: map['rejected'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'confirmed': confirmed,
        'pending': pending,
        'rejected': rejected,
      };
}

class ShiftLoadAvailabilityCoverage {
  final int availableDays;
  final int unavailableDays;
  final int unknownDays;

  const ShiftLoadAvailabilityCoverage({
    required this.availableDays,
    required this.unavailableDays,
    required this.unknownDays,
  });

  factory ShiftLoadAvailabilityCoverage.fromMap(Map<String, dynamic> map) {
    return ShiftLoadAvailabilityCoverage(
      availableDays: map['availableDays'] as int? ?? 0,
      unavailableDays: map['unavailableDays'] as int? ?? 0,
      unknownDays: map['unknownDays'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'availableDays': availableDays,
        'unavailableDays': unavailableDays,
        'unknownDays': unknownDays,
      };
}
