import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'local_store.dart';

/// HTTP helpers that attach JWT Bearer and retry once after refresh on 401.
class ApiHttp {
  ApiHttp._();

  static Future<Map<String, String>> authHeaders({
    Map<String, String>? extra,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?extra,
    };
    final token = await LocalStore.instance.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<http.Response> get(Uri uri, {Duration? timeout}) =>
      _send(() async {
        final headers = await authHeaders();
        final req = http.get(uri, headers: headers);
        return timeout == null ? req : req.timeout(timeout);
      });

  static Future<http.Response> post(
    Uri uri, {
    Object? body,
    Duration? timeout,
  }) =>
      _send(() async {
        final headers = await authHeaders();
        final req = http.post(uri, headers: headers, body: body);
        return timeout == null ? req : req.timeout(timeout);
      });

  static Future<http.Response> put(
    Uri uri, {
    Object? body,
    Duration? timeout,
  }) =>
      _send(() async {
        final headers = await authHeaders();
        final req = http.put(uri, headers: headers, body: body);
        return timeout == null ? req : req.timeout(timeout);
      });

  static Future<http.Response> delete(Uri uri, {Duration? timeout}) =>
      _send(() async {
        final headers = await authHeaders();
        final req = http.delete(uri, headers: headers);
        return timeout == null ? req : req.timeout(timeout);
      });

  static Future<http.Response> _send(
    Future<http.Response> Function() run,
  ) async {
    var response = await run();
    if (response.statusCode != 401) return response;

    final refreshed = await AuthService.instance.refreshTokens();
    if (!refreshed) return response;
    return run();
  }
}
