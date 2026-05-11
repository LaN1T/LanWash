enum UserRole { client, admin, washer }

class User {
  final String id;
  final String username;
  final String displayName;
  final UserRole role;

  User({
    required this.id,
    required this.username,
    required this.displayName,
    required this.role,
  });

  User copyWith({
    String? id,
    String? username,
    String? displayName,
    UserRole? role,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
    );
  }
}
