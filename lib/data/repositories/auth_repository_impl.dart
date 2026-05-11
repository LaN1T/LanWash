import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/remote/auth_api.dart';
import '../models/user_dto.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthApi api;
  AuthRepositoryImpl(this.api);
  
  @override
  Future<User?> login(String username, String password) async {
    final dto = await api.login(username, password);
    return dto?.toEntity();
  }
  @override
  Future<bool> register(User user) async => await api.register(user);
  @override
  Future<void> logout() async => await api.logout();
}
