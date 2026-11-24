import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../../../shared/models/user.dart';

enum AuthStatus { unknown, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.loading = false,
    this.error,
  });

  const AuthState.unknown() : this(status: AuthStatus.unknown);
  const AuthState.unauthenticated({String? error})
      : this(status: AuthStatus.unauthenticated, error: error);

  final AuthStatus status;
  final User? user;
  final bool loading;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isResolved => status != AuthStatus.unknown;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    final api = ref.read(apiClientProvider);
    api.onUnauthorized = _onSessionExpired;
    ref.onDispose(() => api.onUnauthorized = null);
    return const AuthState.unknown();
  }

  void _onSessionExpired() {
    state = const AuthState.unauthenticated(
      error: 'Your session expired. Please sign in again.',
    );
  }

  /// Restores a session from secure storage on app start.
  Future<void> bootstrap() async {
    final storage = ref.read(tokenStorageProvider);
    final accessToken = await storage.readAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      state = const AuthState.unauthenticated();
      return;
    }
    try {
      final json = await ref.read(apiClientProvider).getJson('/users/me');
      state = AuthState(status: AuthStatus.authenticated, user: User.fromJson(json));
    } catch (_) {
      await storage.clear();
      state = const AuthState.unauthenticated();
    }
  }

  /// Returns null on success, or a user-facing error message.
  Future<String?> login(String email, String password) {
    return _authenticate('/auth/login', email: email, password: password);
  }

  /// Returns null on success, or a user-facing error message.
  Future<String?> register(String email, String password) {
    return _authenticate('/auth/register', email: email, password: password);
  }

  Future<String?> _authenticate(
    String path, {
    required String email,
    required String password,
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final json = await ref.read(apiClientProvider).postJson(
        path,
        data: {'email': email.trim(), 'password': password},
      );
      final tokens = json['tokens'] as Map<String, dynamic>;
      final user = User.fromJson(json['user'] as Map<String, dynamic>);
      await ref.read(tokenStorageProvider).saveTokens(
            accessToken: tokens['access_token'] as String,
            refreshToken: tokens['refresh_token'] as String,
          );
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return null;
    } on ApiException catch (error) {
      state = const AuthState.unauthenticated();
      return error.message;
    } catch (_) {
      state = const AuthState.unauthenticated();
      return 'Something went wrong. Please try again.';
    }
  }

  Future<void> logout() async {
    final refreshToken = await ref.read(tokenStorageProvider).readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await ref
            .read(apiClientProvider)
            .postJson('/auth/logout', data: {'refresh_token': refreshToken});
      } catch (_) {
        // Local sign-out must succeed even when the server is unreachable.
      }
    }
    await ref.read(tokenStorageProvider).clear();
    state = const AuthState.unauthenticated();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
