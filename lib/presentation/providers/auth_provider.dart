import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/auth/login_usecase.dart';
import '../../domain/usecases/auth/logout_usecase.dart';
import '../../domain/usecases/auth/check_session_usecase.dart';
import '../../domain/usecases/auth/change_password_usecase.dart';
import 'app_providers.dart';
import 'permission_provider.dart';

// ── Use case providers ────────────────────────────────────────────────────────

final loginUseCaseProvider = Provider<LoginUseCase>((ref) {
  return LoginUseCase(
    ref.read(appDatabaseProvider),
    ref.read(secureStorageProvider),
    ref.read(apiClientProvider),
  );
});

final logoutUseCaseProvider = Provider<LogoutUseCase>((ref) {
  return LogoutUseCase(
    ref.read(appDatabaseProvider),
    ref.read(secureStorageProvider),
  );
});

final checkSessionUseCaseProvider = Provider<CheckSessionUseCase>((ref) {
  return CheckSessionUseCase(
    ref.read(appDatabaseProvider),
    ref.read(secureStorageProvider),
  );
});

final changePasswordUseCaseProvider = Provider<ChangePasswordUseCase>((ref) {
  return ChangePasswordUseCase(ref.read(appDatabaseProvider));
});

// ── Auth state ────────────────────────────────────────────────────────────────

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserEntity user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}

// ── Auth notifier ─────────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthInitial());

  final Ref _ref;

  Future<void> checkSession() async {
    state = const AuthLoading();
    try {
      final user =
          await _ref.read(checkSessionUseCaseProvider).call();
      if (user != null) {
        _ref.invalidate(userPermissionsProvider);
        await _ref.read(userPermissionsProvider.future);
        state = AuthAuthenticated(user);
      } else {
        state = const AuthUnauthenticated();
      }
    } catch (_) {
      state = const AuthUnauthenticated();
    }
  }

  Future<LoginResult> login(String username, String password) async {
    state = const AuthLoading();
    final result =
        await _ref.read(loginUseCaseProvider).call(username, password);
    if (result is LoginSuccess) {
      _ref.invalidate(userPermissionsProvider);
      await _ref.read(userPermissionsProvider.future);
      state = AuthAuthenticated(result.user);
    } else {
      state = const AuthUnauthenticated();
    }
    return result;
  }

  Future<void> logout() async {
    final currentUser = state is AuthAuthenticated
        ? (state as AuthAuthenticated).user
        : null;
    state = const AuthLoading();
    
    if (currentUser != null) {
      await _ref.read(logoutUseCaseProvider).call(currentUser.id);
    }
    _ref.invalidate(userPermissionsProvider);
    state = const AuthUnauthenticated();
  }

  UserEntity? get currentUser =>
      state is AuthAuthenticated ? (state as AuthAuthenticated).user : null;
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});

final currentUserProvider = Provider<UserEntity?>((ref) {
  final state = ref.watch(authProvider);
  if (state is AuthAuthenticated) return state.user;
  return null;
});
