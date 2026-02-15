part of 'auth_bloc.dart';

/// Authentication status.
enum AuthStatus {
  /// Initial state before any check has been made.
  initial,

  /// A request is in progress (checking token, logging in, etc.).
  loading,

  /// User is authenticated and has a valid session.
  authenticated,

  /// User is not authenticated (no token or token expired).
  unauthenticated,

  /// Authentication attempt failed (wrong credentials, network error, etc.).
  failure,
}

/// Immutable authentication state.
class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage];
}
