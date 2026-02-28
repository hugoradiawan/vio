import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:grpc/grpc.dart';

import '../../../core/auth/token_storage.dart';
import '../../../core/grpc/grpc_client.dart';
import '../../../gen/vio/v1/auth.pbgrpc.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// Manages authentication state: login, register, logout, and token restore.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  static const Duration _startupAuthRpcTimeout = Duration(seconds: 8);
  static const Duration _interactiveAuthRpcTimeout = Duration(seconds: 10);

  AuthBloc({
    required AuthServiceClient authClient,
    TokenStorage? tokenStorage,
  })  : _authClient = authClient,
        _tokenStorage = tokenStorage ?? TokenStorage.instance,
        super(const AuthState()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
  }

  final AuthServiceClient _authClient;
  final TokenStorage _tokenStorage;

  /// Check for existing session on app startup.
  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      final accessToken = await _tokenStorage.getAccessToken();
      debugPrint(
        '[AuthBloc] Startup check: accessToken=${accessToken != null ? '${accessToken.substring(0, 10)}...' : 'null'}',
      );
      if (accessToken == null) {
        debugPrint('[AuthBloc] No stored token, going to unauthenticated');
        emit(state.copyWith(status: AuthStatus.unauthenticated));
        return;
      }

      // Validate the stored token with the backend
      final response = await _authClient
          .validateToken(
            ValidateTokenRequest()..accessToken = accessToken,
          )
          .timeout(_startupAuthRpcTimeout);
      debugPrint('[AuthBloc] ValidateToken response: valid=${response.valid}');

      if (response.valid && response.hasUser()) {
        // Restore auth state
        GrpcClient.instance.setAuthToken(accessToken);
        emit(
          state.copyWith(
            status: AuthStatus.authenticated,
            user: response.user,
          ),
        );
      } else {
        // Token invalid — try refresh
        debugPrint('[AuthBloc] Access token invalid, trying refresh...');
        final refreshToken = await _tokenStorage.getRefreshToken();
        if (refreshToken != null) {
          await _tryRefreshToken(refreshToken, emit);
        } else {
          debugPrint('[AuthBloc] No refresh token, clearing');
          await _tokenStorage.clearTokens();
          emit(state.copyWith(status: AuthStatus.unauthenticated));
        }
      }
    } on GrpcError catch (e) {
      debugPrint('[AuthBloc] Token check failed: $e');
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    } catch (e) {
      debugPrint('[AuthBloc] Startup auth check unexpected failure: $e');
      await _tokenStorage.clearTokens();
      GrpcClient.instance.clearAuthToken();
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  /// Login with email and password.
  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      debugPrint('[AuthBloc] Login RPC started');
      final response = await _authClient
          .login(
            LoginRequest()
              ..email = event.email
              ..password = event.password,
          )
          .timeout(_interactiveAuthRpcTimeout);
      debugPrint('[AuthBloc] Login RPC completed');

      await _handleAuthResponse(response, emit);
    } on TimeoutException {
      debugPrint('[AuthBloc] Login RPC timed out');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: 'Login timed out. Please try again.',
        ),
      );
    } on GrpcError catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: _userFriendlyError(e),
        ),
      );
    } catch (e) {
      debugPrint('[AuthBloc] Login error: $e');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: 'An unexpected error occurred.',
        ),
      );
    }
  }

  /// Register a new account.
  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));

    try {
      debugPrint('[AuthBloc] Register RPC started');
      final response = await _authClient
          .register(
            RegisterRequest()
              ..email = event.email
              ..password = event.password
              ..name = event.name,
          )
          .timeout(_interactiveAuthRpcTimeout);
      debugPrint('[AuthBloc] Register RPC completed');

      await _handleAuthResponse(response, emit);
    } on TimeoutException {
      debugPrint('[AuthBloc] Register RPC timed out');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: 'Registration timed out. Please try again.',
        ),
      );
    } on GrpcError catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: _userFriendlyError(e),
        ),
      );
    } catch (e) {
      debugPrint('[AuthBloc] Register error: $e');
      emit(
        state.copyWith(
          status: AuthStatus.failure,
          errorMessage: 'An unexpected error occurred.',
        ),
      );
    }
  }

  /// Logout and clear tokens.
  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final refreshToken = await _tokenStorage.getRefreshToken();
      if (refreshToken != null) {
        await _authClient
            .logout(
              LogoutRequest()..refreshToken = refreshToken,
            )
            .timeout(_interactiveAuthRpcTimeout);
      }
    } catch (_) {
      // Logout is best-effort; continue even if the server call fails
    }

    GrpcClient.instance.clearAuthToken();
    await _tokenStorage.clearTokens();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  // ─── Helpers ─────────────────────────────────────────────

  Future<void> _handleAuthResponse(
    AuthResponse response,
    Emitter<AuthState> emit,
  ) async {
    debugPrint('[AuthBloc] _handleAuthResponse: saving tokens...');
    await _tokenStorage.saveTokens(
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
    );
    debugPrint('[AuthBloc] _handleAuthResponse: setting auth token...');
    GrpcClient.instance.setAuthToken(response.accessToken);

    debugPrint(
      '[AuthBloc] _handleAuthResponse: emitting authenticated '
      '(user=${response.user.id})',
    );
    emit(
      state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
      ),
    );
  }

  Future<void> _tryRefreshToken(
    String refreshToken,
    Emitter<AuthState> emit,
  ) async {
    try {
      debugPrint('[AuthBloc] Attempting token refresh...');
      final response = await _authClient
          .refreshToken(
            RefreshTokenRequest()..refreshToken = refreshToken,
          )
          .timeout(_interactiveAuthRpcTimeout);
      debugPrint('[AuthBloc] Token refresh succeeded');
      await _handleAuthResponse(response, emit);
    } catch (e) {
      debugPrint('[AuthBloc] Token refresh failed: $e');
      await _tokenStorage.clearTokens();
      GrpcClient.instance.clearAuthToken();
      emit(state.copyWith(status: AuthStatus.unauthenticated));
    }
  }

  String _userFriendlyError(GrpcError e) {
    return switch (e.code) {
      StatusCode.unauthenticated => 'Invalid email or password.',
      StatusCode.alreadyExists => 'An account with this email already exists.',
      StatusCode.invalidArgument => e.message ?? 'Invalid input.',
      StatusCode.unavailable => 'Server unreachable. Check your connection.',
      _ => e.message ?? 'An unexpected error occurred.',
    };
  }
}
