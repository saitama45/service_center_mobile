import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/errors/failures.dart';
import '../../../data/datasources/remote/api_client.dart';
import '../../../database/app_database.dart';
import '../../entities/user_entity.dart';

sealed class LoginResult {
  const LoginResult();
}

class LoginSuccess extends LoginResult {
  const LoginSuccess(this.user);
  final UserEntity user;
}

class LoginFailure extends LoginResult {
  const LoginFailure(this.failure);
  final Failure failure;
}

/// Handles the transition from local-only to Remote-First login.
/// 1. Authenticate against the Middleware API.
/// 2. Store the JWT token securely.
/// 3. Upsert the user profile into the local SQLite DB for offline access.
class LoginUseCase {
  const LoginUseCase(this._db, this._secureStorage, this._apiClient);

  final AppDatabase _db;
  final FlutterSecureStorage _secureStorage;
  final ApiClient _apiClient;

  static const String _tokenStorageKey = 'session_token';

  Future<LoginResult> call(String username, String password) async {
    debugPrint('Login: Attempting remote login for "$username" at ${_apiClient.baseUrl}');

    try {
      // Fetch device name for the backend requirements
      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Mobile App';
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = iosInfo.name;
      }

      // 1. Call the Middleware API with required fields: email, password, device_name
      final response = await _apiClient.post('/api/login', {
        'email': username, // Your backend expects 'email'
        'password': password,
        'device_name': deviceName, // Your backend expects 'device_name'
      });

      debugPrint('Login: API Response status: ${response.statusCode}');
      debugPrint('Login: API Response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        final String? token = data['token'];
        final Map<String, dynamic>? userJson = data['user'];

        if (token == null || userJson == null) {
          debugPrint('Login: CRITICAL: Missing token or user in response');
          return const LoginFailure(UnexpectedFailure('Invalid server response: missing data'));
        }

        // 2. Store JWT token securely
        await _secureStorage.write(key: _tokenStorageKey, value: token);

        // 3. Manually map the backend JSON to our local User model
        // Backend returns: {"id":1, "first_name":"...", "last_name":"...", "email":"...", "roles":["admin"]}
        // We need to convert this to match our Drift schema.
        final String userId = userJson['id'].toString();
        final String fullName = '${userJson['first_name'] ?? ''} ${userJson['last_name'] ?? ''}'.trim();
        final String email = userJson['email'] ?? '';
        
        // Use the first role as the roleId for now, or a default if empty
        final String roleName = (userJson['roles'] as List? ?? []).isNotEmpty 
            ? userJson['roles'][0] 
            : 'user';

        // We need a roleId that exists in our Roles table. 
        // For simplicity during migration, we'll try to find or create this role.
        // For now, let's assume 'admin' maps to a constant UUID or we use the name.
        final String roleId = roleName; 

        final now = DateTime.now().toUtc();
        final user = User(
          id: userId,
          username: email,
          fullName: fullName,
          email: email,
          passwordHash: 'REMOTE_AUTH',
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

        // 4. Map to entity
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
      } else if (response.statusCode == 401 || response.statusCode == 422) {
        // Laravel Sanctum returns 422 for wrong credentials, 401 for bad tokens.
        // Parse the body to surface a specific message when available.
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
      debugPrint('Login: Error during remote authentication: $e');
      return const LoginFailure(NetworkFailure('Could not reach the server. Ensure your API is running.'));
    }
  }

  Future<LoginResult> _attemptLocalLogin(String username, String password) async {
     return const LoginFailure(NetworkFailure('Server unreachable')); 
  }
}
