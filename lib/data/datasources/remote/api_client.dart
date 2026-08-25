import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  // Production Cloud API by default. Override for local testing without
  // touching this file: `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8010`
  // (10.0.2.2 is the Android emulator's alias for the host machine's
  // loopback — see docs/knowledge/Integrations.md). Omitting the define
  // builds against production exactly as before.
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://support.tablegroup.com.ph',
  );
  static const String _tokenKey = 'session_token';
  static const Duration _timeout = Duration(seconds: 10);

  String get baseUrl => _baseUrl;

  Future<Map<String, String>> _getHeaders() async {
    final token = await _secureStorage.read(key: _tokenKey);
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<http.Response> get(String path) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final url = Uri.parse('$_baseUrl$normalizedPath');
    final headers = await _getHeaders();
    return http.get(url, headers: headers).timeout(_timeout);
  }

  /// [timeout] overrides the default 10s budget — needed by endpoints that
  /// do real synchronous work server-side (the OTP send route sends mail
  /// over SMTP inline; see `OtpRemoteDatasource`) rather than just querying
  /// a database.
  Future<http.Response> post(String path, dynamic body, {Duration? timeout}) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final url = Uri.parse('$_baseUrl$normalizedPath');
    final headers = await _getHeaders();
    return http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(timeout ?? _timeout);
  }

  Future<http.Response> put(String path, dynamic body) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final url = Uri.parse('$_baseUrl$normalizedPath');
    final headers = await _getHeaders();
    return http.put(
      url,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(_timeout);
  }

  Future<http.Response> delete(String path) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final url = Uri.parse('$_baseUrl$normalizedPath');
    final headers = await _getHeaders();
    return http.delete(url, headers: headers).timeout(_timeout);
  }
}
