part of 'auth_bloc.dart';

/// Base class for authentication events.
sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Check for an existing session on app startup.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Login with email and password.
class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// Register a new account.
class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.email,
    required this.password,
    required this.name,
  });

  final String email;
  final String password;
  final String name;

  @override
  List<Object?> get props => [email, password, name];
}

/// Logout and clear tokens.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}
