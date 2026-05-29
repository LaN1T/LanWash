import 'package:crypto/crypto.dart';
import 'dart:convert';

enum UserRole { client, admin, washer }

class User {
  final int? id;
  final String username;
  final String passwordHash;
  final UserRole role;
  final String displayName;
  final String phone;
  final String carModel;
  final String carNumber;
  final DateTime createdAt;
  final bool isFavoriteAdmin; // для уведомлений у админа

  const User({
    this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.displayName,
    this.phone = '',
    this.carModel = '',
    this.carNumber = '',
    required this.createdAt,
    this.isFavoriteAdmin = false,
  });

  static String hashPassword(String password) {
    final bytes = utf8.encode(password);
    return sha256.convert(bytes).toString();
  }

  static bool checkPassword(String password, String hash) {
    return hashPassword(password) == hash;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'username': username,
        'passwordHash': passwordHash,
        'role': role.name,
        'displayName': displayName,
        'phone': phone,
        'carModel': carModel,
        'carNumber': carNumber,
        'createdAt': createdAt.toIso8601String(),
        'isFavoriteAdmin': isFavoriteAdmin ? 1 : 0,
      };

  factory User.fromMap(Map<String, dynamic> m) => User(
        id: m['id'] as int?,
        username: m['username'] ?? '',
        passwordHash: m['passwordHash'] ?? '',
        role: UserRole.values.firstWhere((r) => r.name == m['role'],
            orElse: () => UserRole.client),
        displayName: m['displayName'] ?? m['username'] ?? '',
        phone: m['phone'] ?? '',
        carModel: m['carModel'] ?? '',
        carNumber: m['carNumber'] ?? '',
        createdAt: m['createdAt'] != null
            ? DateTime.parse(m['createdAt'])
            : DateTime.now(),
        isFavoriteAdmin: m['isFavoriteAdmin'] == 1,
      );

  User copyWith({
    String? displayName,
    String? phone,
    String? carModel,
    String? carNumber,
    String? passwordHash,
    bool? isFavoriteAdmin,
  }) =>
      User(
        id: id,
        username: username,
        passwordHash: passwordHash ?? this.passwordHash,
        role: role,
        displayName: displayName ?? this.displayName,
        phone: phone ?? this.phone,
        carModel: carModel ?? this.carModel,
        carNumber: carNumber ?? this.carNumber,
        createdAt: createdAt,
        isFavoriteAdmin: isFavoriteAdmin ?? this.isFavoriteAdmin,
      );
}
