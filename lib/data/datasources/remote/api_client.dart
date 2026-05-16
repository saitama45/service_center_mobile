import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  ApiClient(this._secureStorage);

  final FlutterSecureStorage _secureStorage;

  // Production Cloud API
  static const String _baseUrl = 'https://support.tablegroup.com.ph';
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

  Future<http.Response> post(String path, dynamic body) async {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final url = Uri.parse('$_baseUrl$normalizedPath');
    final headers = await _getHeaders();
    return http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    ).timeout(_timeout);
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
