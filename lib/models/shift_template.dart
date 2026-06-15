class ShiftTemplateSlot {
  final int weekday; // 1=Monday ... 7=Sunday
  final String startTime; // HH:MM
  final String endTime; // HH:MM

  const ShiftTemplateSlot({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  });

  factory ShiftTemplateSlot.fromMap(Map<String, dynamic> map) {
    return ShiftTemplateSlot(
      weekday: map['weekday'] as int,
      startTime: map['startTime'] as String,
      endTime: map['endTime'] as String,
    );
  }

  Map<String, dynamic> toMap() => {
        'weekday': weekday,
        'startTime': startTime,
        'endTime': endTime,
      };
}

class ShiftTemplate {
  final int id;
  final String ownerUsername;
  final String name;
  final bool isDefault;
  final List<ShiftTemplateSlot> slots;

  const ShiftTemplate({
    required this.id,
    required this.ownerUsername,
    required this.name,
    required this.isDefault,
    required this.slots,
  });

  factory ShiftTemplate.fromMap(Map<String, dynamic> map) {
    final rawSlots = (map['slots'] as List<dynamic>?) ?? [];
    return ShiftTemplate(
      id: map['id'] as int,
      ownerUsername: map['ownerUsername'] as String,
      name: map['name'] as String,
      isDefault: map['isDefault'] as bool? ?? false,
      slots: rawSlots
          .cast<Map<String, dynamic>>()
          .map(ShiftTemplateSlot.fromMap)
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'ownerUsername': ownerUsername,
        'name': name,
        'isDefault': isDefault,
        'slots': slots.map((s) => s.toMap()).toList(),
      };

  ShiftTemplate copyWith({
    int? id,
    String? ownerUsername,
    String? name,
    bool? isDefault,
    List<ShiftTemplateSlot>? slots,
  }) {
    return ShiftTemplate(
      id: id ?? this.id,
      ownerUsername: ownerUsername ?? this.ownerUsername,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      slots: slots ?? this.slots,
    );
  }
}
