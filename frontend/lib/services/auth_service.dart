import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'local_store.dart';

class AuthSession {
  AuthSession({
    required this.userName,
    required this.accessToken,
    required this.refreshToken,
    this.userId,
    this.email,
  });

  final String userName;
  final String accessToken;
  final String refreshToken;
  final String? userId;
  final String? email;

  factory AuthSession.fromJson(Map<String, dynamic> json, {String? fallbackUserName}) {
    return AuthSession(
      userName: json['userName'] as String? ?? fallbackUserName ?? '',
      accessToken: json['accessToken'] as String? ?? '',
      refreshToken: json['refreshToken'] as String? ?? '',
      userId: json['userId'] as String?,
      email: json['email'] as String?,
    );
  }
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  String get _base => ApiConfig.baseUrl;

  Future<bool>? _refreshInFlight;

  Future<AuthSession> login(String usernameOrEmail, String password) async {
    final response = await http
        .post(
          Uri.parse('$_base/api/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': usernameOrEmail,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));
    _check(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final session = AuthSession.fromJson(json, fallbackUserName: usernameOrEmail);
    if (session.accessToken.isEmpty || session.refreshToken.isEmpty) {
      throw AuthException(500, '{"error":"A szerver nem adott tokent. Próbáld újra."}');
    }
    return session;
  }

  /// Requests a temporary password emailed to [email].
  Future<String> forgotPassword(String email) async {
    final response = await http
        .post(
          Uri.parse('$_base/api/auth/forgot-password'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email.trim()}),
        )
        .timeout(const Duration(seconds: 15));
    _check(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return json['message'] as String? ??
        'Ha van fiók ezzel az e-mail címmel, elküldtük az új ideiglenes jelszót.';
  }

  Future<AuthSession> register({
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
            'email': email,
            'password': password,
            'username': username,
            'weightUnit': weightUnit,
            'distanceUnit': distanceUnit,
            'measurementUnit': measurementUnit,
            'weight': weight,
            'county': county,
            'source': source,
          }),
        )
        .timeout(const Duration(seconds: 12));
    _check(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final session = AuthSession.fromJson(json, fallbackUserName: username);
    if (session.accessToken.isEmpty || session.refreshToken.isEmpty) {
      throw AuthException(500, '{"error":"A szerver nem adott tokent. Próbáld újra."}');
    }
    return session;
  }

  /// Returns true if a new access token was stored.
  Future<bool> refreshTokens() async {
    _refreshInFlight ??= _refreshTokensInner();
    try {
      return await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<bool> _refreshTokensInner() async {
    final refresh = await LocalStore.instance.getRefreshToken();
    if (refresh == null || refresh.isEmpty) return false;

    final response = await http
        .post(
          Uri.parse('$_base/api/auth/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refreshToken': refresh}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final access = json['accessToken'] as String? ?? '';
    final nextRefresh = json['refreshToken'] as String? ?? '';
    if (access.isEmpty || nextRefresh.isEmpty) return false;

    await LocalStore.instance.setTokens(
      accessToken: access,
      refreshToken: nextRefresh,
    );
    final userName = json['userName'] as String?;
    if (userName != null && userName.isNotEmpty) {
      ApiConfig.defaultUserName = userName;
    }
    return true;
  }

  Future<void> logout() async {
    final refresh = await LocalStore.instance.getRefreshToken();
    try {
      if (refresh != null && refresh.isNotEmpty) {
        await http
            .post(
              Uri.parse('$_base/api/auth/logout'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refreshToken': refresh}),
            )
            .timeout(const Duration(seconds: 8));
      }
    } catch (_) {
      // Local clear still happens.
    }
    await LocalStore.instance.clearSession();
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
