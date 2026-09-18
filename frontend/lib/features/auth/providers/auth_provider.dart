import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scanserve/core/network/dio_client.dart';
import 'package:scanserve/features/auth/state/auth_state.dart';
import 'package:scanserve/shared/models/app_user.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState()) {
    _bootstrap();
  }

  final Ref _ref;

  Dio get _dio => _ref.read(dioProvider);

  /// Runs once on app start: if a token is already stored, validate it
  /// against GET /api/auth/me. An expired/invalid token just results in
  /// "unauthenticated" - the router sends the user to /login.
  Future<void> _bootstrap() async {
    final token = _ref.read(tokenStorageProvider).token;
    if (token == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    try {
      final response = await _dio.get('/auth/me');
      final user = AppUser.fromMeJson(response.data['user'] as Map<String, dynamic>);
      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on DioException {
      await _ref.read(tokenStorageProvider).clear();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Throws a DioException on failure - screens should catch this and
  /// show apiErrorMessage(error) to the user.
  Future<void> login({required String email, required String password}) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    final token = response.data['token'] as String;
    await _ref.read(tokenStorageProvider).setToken(token);

    // The login response's user shape is slimmer than /me's - fetch the
    // full profile (with restaurant name) right away so the dashboard
    // has everything it needs without a second round trip on first paint.
    final meResponse = await _dio.get('/auth/me');
    final user = AppUser.fromMeJson(meResponse.data['user'] as Map<String, dynamic>);

    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Future<void> logout() async {
    await _ref.read(tokenStorageProvider).clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
