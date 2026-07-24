import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// Daily food logging streak — stored on the server.
class StreakService {
  StreakService._();
  static final StreakService instance = StreakService._();

  Future<int> getStreak() => fetch();

  /// Call when the user just logged food today.
  Future<int> onFoodLogged() => refreshAndGet(true);

  static String get _base => ApiConfig.baseUrl;
  static String get _user => ApiConfig.defaultUserName;

  static Future<int> refreshAndGet(bool hasFoodToday) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/api/nutrition/streak'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userName': _user,
              'hasFoodToday': hasFoodToday,
            }),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['streak'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  static Future<int> fetch() async {
    try {
      final response = await http
          .get(Uri.parse(
              '$_base/api/nutrition/streak?userName=${Uri.encodeComponent(_user)}'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['streak'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }
}
