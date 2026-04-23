import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  // Use FlutterSecureStorage (consistent with AuthService)
  final _storage = const FlutterSecureStorage();

  // Helper to get the saved token
  Future<String?> getAppToken() async {
    return await _storage.read(key: 'appToken');
  }

  /// Decodes a JWT token without external dependencies
  Map<String, dynamic>? decodeJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      final payload = parts[1];
      final String normalized = base64Url.normalize(payload);
      final String decoded = utf8.decode(base64Url.decode(normalized));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      debugPrint(" Error decoding JWT: $e");
      return null;
    }
  }

  /// Extracts the role from the saved token
  Future<String?> getRoleFromToken() async {
    final token = await getAppToken();
    if (token == null) return null;
    final payload = decodeJwt(token);
    return payload?['role'] ?? payload?['UserRole'] ?? payload?['userRole'];
  }

  // Helper to build the correct headers
  Future<Map<String, String>> _getHeaders(bool useAuth) async {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
    };

    if (useAuth) {
      final token = await getAppToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
        // Only log the first few characters for security
        debugPrint(" ApiClient: Token found. Prefix: ${token.substring(0, 10)}...");
      } else {
        debugPrint(" ApiClient: useAuth=true but NO TOKEN found in storage.");
      }
    }
    return headers;
  }

  /// Performs a GET request
  Future<http.Response> get(String url, {bool useAuth = false}) async {
    final headers = await _getHeaders(useAuth);
    return await http.get(
      Uri.parse(url),
      headers: headers,
    );
  }

  /// Performs a POST request
  Future<http.Response> post(String url,
      {dynamic body, bool useAuth = false}) async {
    final headers = await _getHeaders(useAuth);
    return await http.post(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Performs a PUT request
  Future<http.Response> put(String url,
      {dynamic body, bool useAuth = false}) async {
    final headers = await _getHeaders(useAuth);
    return await http.put(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  /// Performs a DELETE request
  Future<http.Response> delete(String url, {bool useAuth = false}) async {
    final headers = await _getHeaders(useAuth);
    return await http.delete(
      Uri.parse(url),
      headers: headers,
    );
  }

  /// Performs a PATCH request
  Future<http.Response> patch(String url,
      {dynamic body, bool useAuth = false}) async {
    final headers = await _getHeaders(useAuth);
    return await http.patch(
      Uri.parse(url),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }
}
