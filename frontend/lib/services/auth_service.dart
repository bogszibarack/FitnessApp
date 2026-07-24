import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  String get _base => ApiConfig.baseUrl;

  Future<String> login(String usernameOrEmail, String password) async {
    final response = await http
        .post(
          Uri.parse('$_base/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'Username': usernameOrEmail,
            'Password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));
    _check(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['userName'] as String? ?? usernameOrEmail;
  }

  Future<String> register({
    required String email,
    required String password,
    required String username,
    String weightUnit = 'kg',
    String distanceUnit = 'km',
    String measurementUnit = 'cm',
    double weight = 0,
    String county = '',
    String source = '',
  }) async {
    final response = await http
        .post(
          Uri.parse('$_base/api/auth/register-onboarding'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'Email': email,
            'Password': password,
            'Username': username,
            'WeightUnit': weightUnit,
            'DistanceUnit': distanceUnit,
            'MeasurementUnit': measurementUnit,
            'Weight': weight,
            'County': county,
            'Source': source,
          }),
        )
        .timeout(const Duration(seconds: 12));
    _check(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['userName'] as String? ?? username;
  }

  Future<bool> checkEmail(String email) async {
    final uri = Uri.parse('$_base/api/auth/check-email').replace(
      queryParameters: {'email': email},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return false;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['occupied'] == true;
  }

  Future<bool> checkUsername(String username) async {
    final uri = Uri.parse('$_base/api/auth/check-username').replace(
      queryParameters: {'username': username},
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return false;
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['occupied'] == true;
  }

  void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(response.statusCode, response.body);
    }
  }
}

class AuthException implements Exception {
  AuthException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  String? get errorMessage {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['error'] as String?;
    } catch (_) {
      return null;
    }
  }

  @override
  String toString() => 'AuthException($statusCode): $body';
}
