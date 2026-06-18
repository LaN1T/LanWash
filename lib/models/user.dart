enum UserRole { client, admin, washer }

class User {
  final int? id;
  final String username;
  final String passwordHash;
  final UserRole role;
  final String displayName;
  final String email;
  final String phone;
  final String carModel;
  final String carNumber;
  final String avatarUrl;
  final DateTime createdAt;
  final bool isFavoriteAdmin;

  const User({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.displayName,
    this.email = '',
    this.phone = '',
    this.carModel = '',
    this.carNumber = '',
    this.avatarUrl = '',
    required this.createdAt,
    this.isFavoriteAdmin = false,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'username': username,
        // Безопасность: никогда не храним хеш пароля на клиенте
        'role': role.name,
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'carModel': carModel,
        'carNumber': carNumber,
        'avatarUrl': avatarUrl,
        'createdAt': createdAt.toIso8601String(),
        'isFavoriteAdmin': isFavoriteAdmin ? 1 : 0,
      };

  factory User.fromMap(Map<String, dynamic> m) => User(
        id: m['id'] as int?,
        username: m['username'] ?? '',
        passwordHash: '', // Never store password hash on client
        role: UserRole.values.firstWhere((r) => r.name == m['role'],
            orElse: () => UserRole.client),
        displayName: m['displayName'] ?? m['username'] ?? '',
        email: m['email'] ?? '',
        phone: m['phone'] ?? '',
        carModel: m['carModel'] ?? '',
        carNumber: m['carNumber'] ?? '',
        avatarUrl: m['avatarUrl'] ?? '',
        createdAt: m['createdAt'] != null
            ? DateTime.parse(m['createdAt'])
            : DateTime.now(),
        isFavoriteAdmin: m['isFavoriteAdmin'] == 1,
      );

  User copyWith({
    String? displayName,
    String? email,
    String? phone,
    String? carModel,
    String? carNumber,
    String? avatarUrl,
    String? passwordHash,
    bool? isFavoriteAdmin,
  }) =>
      User(
        id: id,
        username: username,
        passwordHash: passwordHash ?? this.passwordHash,
        role: role,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        carModel: carModel ?? this.carModel,
        carNumber: carNumber ?? this.carNumber,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt,
        isFavoriteAdmin: isFavoriteAdmin ?? this.isFavoriteAdmin,
      );
}
