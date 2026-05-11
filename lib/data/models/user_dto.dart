import '../../domain/entities/user.dart';

class UserDto {
  final int? id;
  final String username;
  final String passwordHash;
  final String role;
  final String displayName;
  final String phone;
  final String carModel;
  final String carNumber;
  final String createdAt;
  final int isFavoriteAdmin;

  UserDto({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.displayName,
    required this.phone,
    required this.carModel,
    required this.carNumber,
    required this.createdAt,
    required this.isFavoriteAdmin,
  });

  factory UserDto.fromMap(Map<String, dynamic> m) => UserDto(
    id: m['id'] as int?,
    username: m['username'] ?? '',
    passwordHash: m['passwordHash'] ?? '',
    role: m['role'] ?? 'client',
    displayName: m['displayName'] ?? '',
    phone: m['phone'] ?? '',
    carModel: m['carModel'] ?? '',
    carNumber: m['carNumber'] ?? '',
    createdAt: m['createdAt'] ?? DateTime.now().toIso8601String(),
    isFavoriteAdmin: (m['isFavoriteAdmin'] == 1 || m['isFavoriteAdmin'] == true) ? 1 : 0,
  );

  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'username': username,
    'passwordHash': passwordHash,
    'role': role,
    'displayName': displayName,
    'phone': phone,
    'carModel': carModel,
    'carNumber': carNumber,
    'createdAt': createdAt,
    'isFavoriteAdmin': isFavoriteAdmin,
  };

  User toEntity() => User(
    id: id,
    username: username,
    passwordHash: passwordHash,
    role: UserRole.values.firstWhere((r) => r.name == role, orElse: () => UserRole.client),
    displayName: displayName,
    phone: phone,
    carModel: carModel,
    carNumber: carNumber,
    createdAt: DateTime.parse(createdAt),
    isFavoriteAdmin: isFavoriteAdmin == 1,
  );
}
