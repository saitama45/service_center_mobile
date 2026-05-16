import 'dart:convert';
import 'dart:io';
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/token_util.dart';
import '../../../data/datasources/remote/api_client.dart';
import '../../../database/app_database.dart';
import '../../entities/user_entity.dart';

sealed class LoginResult {
  const LoginResult();
}

class LoginSuccess extends LoginResult {
  const LoginSuccess(this.user, {this.isOffline = false});
  final UserEntity user;
  final bool isOffline;
}

class LoginFailure extends LoginResult {
  const LoginFailure(this.failure);
  final Failure failure;
}

/// Handles the transition from local-only to Remote-First login,
/// with transparent offline fallback for previously-cached users.
class LoginUseCase {
  const LoginUseCase(this._db, this._secureStorage, this._apiClient);

  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage;
  final ApiClient _apiClient;

  static const String _tokenStorageKey = 'session_token';
  static const String _legacyPasswordHashMarker = 'REMOTE_AUTH';
  static const Duration _maxOfflineAge = Duration(days: 14);
  static const int _maxFailedAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 30);

  Future<LoginResult> call(String username, String password) async {
    debugPrint('Login: Attempting remote login for "$username" at ${_apiClient.baseUrl}');

    final deviceName = await _resolveDeviceName();

    try {
      final response = await _apiClient.post('/api/login', {
        'email': username,
        'password': password,
        'device_name': deviceName,
      });

      debugPrint('Login: API Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        return await _handleRemoteSuccess(response.body, password, deviceName);
      } else if (response.statusCode == 401 || response.statusCode == 422) {
        String? serverMessage;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          serverMessage = body['message'] as String?;
        } catch (_) {}
        debugPrint('Login: ${response.statusCode} – $serverMessage');
        return LoginFailure(InvalidCredentialsFailure(
          attemptsRemaining: null,
          serverMessage: serverMessage,
        ));
      } else {
        debugPrint('Login: Unexpected status code ${response.statusCode}');
        return const LoginFailure(UnexpectedFailure('Server error during login'));
      }
    } catch (e) {
      debugPrint('Login: Remote unreachable ($e). Falling back to offline.');
      return _attemptLocalLogin(username, password);
    }
  }

  Future<String> _resolveDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.name;
      }
    } catch (_) {}
    return 'Mobile App';
  }

  Future<LoginResult> _handleRemoteSuccess(
      String body, String plaintextPassword, String deviceName) async {
    final Map<String, dynamic> data = jsonDecode(body);
    final String? token = data['token'];
    final Map<String, dynamic>? userJson = data['user'];

    if (token == null || userJson == null) {
      debugPrint('Login: CRITICAL: Missing token or user in response');
      return const LoginFailure(
          UnexpectedFailure('Invalid server response: missing data'));
    }

    await _secureStorage.write(key: _tokenStorageKey, value: token);

    final String userId = userJson['id'].toString();
    final String fullName =
        '${userJson['first_name'] ?? ''} ${userJson['last_name'] ?? ''}'.trim();
    final String email = userJson['email'] ?? '';
    final String roleName = (userJson['roles'] as List? ?? []).isNotEmpty
        ? userJson['roles'][0]
        : 'user';
    final String roleId = roleName;

    final now = DateTime.now().toUtc();
    final passwordHash = BCrypt.hashpw(plaintextPassword, BCrypt.gensalt());

    final user = User(
      id: userId,
      username: email,
      fullName: fullName,
      email: email,
      passwordHash: passwordHash,
      roleId: roleId,
      isActive: true,
      syncStatus: 0,
      isDeleted: false,
      failedLoginCount: 0,
      lastLoginAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await _db.userDao.upsertUser(user);
    await _db.userDao.resetLoginFailures(userId);

    // Create/refresh local Session row so CheckSessionUseCase can validate
    // the cached JWT on next app restart. Invalidate any stale rows first.
    await _db.sessionDao.invalidateAllUserSessions(userId);
    await _db.sessionDao.createSession(
      userId: userId,
      tokenHash: TokenUtil.hashToken(token),
      deviceInfo: deviceName,
    );

    return LoginSuccess(UserEntity(
      id: user.id,
      roleId: user.roleId,
      roleCode: roleName.toUpperCase(),
      roleName: roleName,
      username: user.username,
      fullName: user.fullName,
      email: user.email,
      isActive: user.isActive,
      failedLoginCount: 0,
      lastLoginAt: now,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    ));
  }

  Future<LoginResult> _attemptLocalLogin(
      String username, String password) async {
    final user = await _db.userDao.findByUsername(username);

    if (user == null ||
        user.passwordHash.isEmpty ||
        user.passwordHash == _legacyPasswordHashMarker) {
      // No usable offline record — surface as network failure so the UI
      // shows the "Could not connect" message.
      return const LoginFailure(NetworkFailure(
          'Could not reach the server and no offline session is available.'));
    }

    if (!user.isActive) {
      return const LoginFailure(AccountDisabledFailure());
    }

    final now = DateTime.now().toUtc();

    if (user.lockedUntil != null && user.lockedUntil!.isAfter(now)) {
      return LoginFailure(AccountLockedFailure(user.lockedUntil!));
    }

    if (user.lastLoginAt == null ||
        now.difference(user.lastLoginAt!) > _maxOfflineAge) {
      return LoginFailure(OfflineSessionExpiredFailure(user.lastLoginAt));
    }

    final passwordOk = _verifyBcrypt(password, user.passwordHash);
    if (!passwordOk) {
      final newCount = user.failedLoginCount + 1;
      final lockUntil =
          newCount >= _maxFailedAttempts ? now.add(_lockoutDuration) : null;
      await _db.userDao.updateLoginFailure(user.id, newCount, lockUntil);

      if (lockUntil != null) {
        return LoginFailure(AccountLockedFailure(lockUntil));
      }
      return LoginFailure(InvalidCredentialsFailure(
        attemptsRemaining: _maxFailedAttempts - newCount,
      ));
    }

    await _db.userDao.resetLoginFailures(user.id);

    // Reuse the cached JWT. The server will reject it once we're online,
    // forcing a fresh online login and token refresh at that point.
    final role = await _db.roleDao.getRoleById(user.roleId);

    return LoginSuccess(
      isOffline: true,
      UserEntity(
      id: user.id,
      roleId: user.roleId,
      roleCode: role?.code ?? user.roleId.toUpperCase(),
      roleName: role?.name ?? user.roleId,
      deoId: user.deoId?.toString(),
      username: user.username,
      fullName: user.fullName,
      email: user.email,
      employeeId: user.employeeId,
      isActive: user.isActive,
      lastLoginAt: now,
      failedLoginCount: 0,
      createdBy: user.createdBy,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    ));
  }

  bool _verifyBcrypt(String password, String hash) {
    try {
      return BCrypt.checkpw(password, hash);
    } catch (e) {
      debugPrint('Login: bcrypt verify failed: $e');
      return false;
    }
  }
}
