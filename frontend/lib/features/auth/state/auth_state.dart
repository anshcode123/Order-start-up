import 'package:scanserve/shared/models/app_user.dart';

enum AuthStatus {
  /// Still checking for a stored token on app start.
  unknown,
  authenticated,
  unauthenticated,
}

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
  });

  final AuthStatus status;
  final AppUser? user;

  AuthState copyWith({AuthStatus? status, AppUser? user}) {
    return AuthState(
      status: status ?? this.status,
      // Explicitly passing null (e.g. on logout) should clear the user,
      // so this can't use `user ?? this.user`.
      user: status == AuthStatus.unauthenticated ? null : (user ?? this.user),
    );
  }
}
