import 'dart:convert';

import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../config/integrations_config.dart';
import 'local_store.dart';

class StravaActivity {
  const StravaActivity({
    required this.id,
    required this.name,
    required this.type,
    required this.startedAt,
    required this.distanceKm,
    required this.durationMinutes,
  });

  final int id;
  final String name;
  final String type;
  final DateTime startedAt;
  final double distanceKm;
  final int durationMinutes;
}

class StravaService {
  StravaService._();
  static final StravaService instance = StravaService._();

  static const _authBase = 'https://www.strava.com/oauth/authorize';
  static const _tokenUrl = 'https://www.strava.com/oauth/token';
  static const _apiBase = 'https://www.strava.com/api/v3';

  bool get isConfigured => IntegrationsConfig.stravaConfigured;

  Future<bool> isConnected() => LocalStore.instance.getStravaConnected();

  Future<void> connect() async {
    if (!isConfigured) {
      throw StravaNotConfiguredException(
        'Strava nincs konfigurálva. Add meg STRAVA_CLIENT_ID és STRAVA_CLIENT_SECRET build időben.',
      );
    }

    final clientId = IntegrationsConfig.stravaClientId;
    final redirect = IntegrationsConfig.stravaRedirectUri;
    final authUrl = Uri.parse(_authBase).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirect,
        'approval_prompt': 'auto',
        'scope': 'activity:read_all',
      },
    );

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme(redirect),
    );

    final returned = Uri.parse(result);
    final code = returned.queryParameters['code'];
    if (code == null || code.isEmpty) {
      throw Exception('Strava engedélyezés sikertelen (nincs code).');
    }

    final tokenResponse = await http.post(
      Uri.parse(_tokenUrl),
      body: {
        'client_id': clientId,
        'client_secret': IntegrationsConfig.stravaClientSecret,
        'code': code,
        'grant_type': 'authorization_code',
        'redirect_uri': redirect,
      },
    );

    if (tokenResponse.statusCode < 200 || tokenResponse.statusCode >= 300) {
      throw Exception('Strava token hiba (${tokenResponse.statusCode}): ${tokenResponse.body}');
    }

    final data = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
    final accessToken = data['access_token'] as String? ?? '';
    final refreshToken = data['refresh_token'] as String? ?? '';
    final expiresAt = data['expires_at'] as int?;

    if (accessToken.isEmpty) {
      throw Exception('Strava nem adott access token-t.');
    }

    await LocalStore.instance.setStravaTokens(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt != null
          ? DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000)
          : null,
    );
    await LocalStore.instance.setStravaConnected(true);
  }

  Future<void> disconnect() async {
    await LocalStore.instance.clearStravaTokens();
    await LocalStore.instance.setStravaConnected(false);
    await LocalStore.instance.setStravaLastSync(null);
    await LocalStore.instance.setStravaLastError(null);
  }

  Future<List<StravaActivity>> syncRecentActivities({int days = 7}) async {
    if (!isConfigured) {
      throw StravaNotConfiguredException(
        'Strava nincs konfigurálva — szinkron nem elérhető.',
      );
    }

    final connected = await isConnected();
    if (!connected) {
      throw Exception('Strava nincs csatlakoztatva.');
    }

    try {
      final accessToken = await _ensureAccessToken();
      final after = DateTime.now().subtract(Duration(days: days));
      final uri = Uri.parse('$_apiBase/athlete/activities').replace(
        queryParameters: {
          'after': (after.millisecondsSinceEpoch ~/ 1000).toString(),
          'per_page': '30',
        },
      );

      final response = await http.get(
        uri,
        headers: {'Authorization': 'Bearer $accessToken'},
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Strava API hiba (${response.statusCode}): ${response.body}');
      }

      final list = jsonDecode(response.body) as List<dynamic>;
      final activities = list.map((raw) {
        final item = raw as Map<String, dynamic>;
        final distanceM = (item['distance'] as num?)?.toDouble() ?? 0;
        final movingSec = (item['moving_time'] as num?)?.toInt() ?? 0;
        final start = item['start_date_local'] as String? ?? '';
        return StravaActivity(
          id: (item['id'] as num?)?.toInt() ?? 0,
          name: item['name'] as String? ?? 'Edzés',
          type: item['type'] as String? ?? 'Workout',
          startedAt: DateTime.tryParse(start) ?? DateTime.now(),
          distanceKm: distanceM / 1000,
          durationMinutes: (movingSec / 60).round(),
        );
      }).toList();

      await LocalStore.instance.setStravaLastSync(DateTime.now());
      await LocalStore.instance.setStravaLastError(null);
      await LocalStore.instance.setStravaActivityCount(activities.length);
      return activities;
    } catch (e) {
      await LocalStore.instance.setStravaLastError(e.toString());
      throw e;
    }
  }

  Future<String> _ensureAccessToken() async {
    final access = await LocalStore.instance.getStravaAccessToken();
    final refresh = await LocalStore.instance.getStravaRefreshToken();
    final expiresAt = await LocalStore.instance.getStravaExpiresAt();

    if (access != null &&
        access.isNotEmpty &&
        (expiresAt == null ||
            expiresAt.isAfter(DateTime.now().add(const Duration(minutes: 5))))) {
      return access;
    }

    if (refresh == null || refresh.isEmpty) {
      throw Exception('Strava token lejárt — csatlakozz újra.');
    }

    final response = await http.post(
      Uri.parse(_tokenUrl),
      body: {
        'client_id': IntegrationsConfig.stravaClientId,
        'client_secret': IntegrationsConfig.stravaClientSecret,
        'grant_type': 'refresh_token',
        'refresh_token': refresh,
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Strava token frissítés sikertelen (${response.statusCode}).');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final newAccess = data['access_token'] as String? ?? '';
    final newRefresh = (data['refresh_token'] as String?) ?? refresh;
    final expires = data['expires_at'] as int?;

    await LocalStore.instance.setStravaTokens(
      accessToken: newAccess,
      refreshToken: newRefresh,
      expiresAt: expires != null
          ? DateTime.fromMillisecondsSinceEpoch(expires * 1000)
          : null,
    );

    return newAccess;
  }

  String _callbackScheme(String redirectUri) {
    final uri = Uri.parse(redirectUri);
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      return uri.host;
    }
    return uri.scheme;
  }
}

class StravaNotConfiguredException implements Exception {
  StravaNotConfiguredException(this.message);
  final String message;

  @override
  String toString() => message;
}
