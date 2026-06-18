class UserStats {
  final int totalAppointments;
  final int totalSpent;
  final String favoriteWashType;
  final String level;
  final int levelProgress;
  final int points;

  const UserStats({
    this.totalAppointments = 0,
    this.totalSpent = 0,
    this.favoriteWashType = '-',
    this.level = 'Новичок',
    this.levelProgress = 0,
    this.points = 0,
  });

  factory UserStats.fromMap(Map<String, dynamic> m) => UserStats(
        totalAppointments: m['totalAppointments'] ?? 0,
        totalSpent: m['totalSpent'] ?? 0,
        favoriteWashType: m['favoriteWashType'] ?? '-',
        level: m['level'] ?? 'Новичок',
        levelProgress: m['levelProgress'] ?? 0,
        points: m['points'] ?? 0,
      );
}
