import 'package:flutter/foundation.dart';

class ApiConfig {
  // Runtime-ban módosítható felhasználónév (onboarding után frissül)
  static String _defaultUserName = 'Koko';
  static String get defaultUserName => _defaultUserName;
  static set defaultUserName(String value) {
    if (value.isNotEmpty) _defaultUserName = value;
  }

  /// Debug módban a lokális backend (dotnet run), release-ben a production.
  static String get baseUrl {
    if (kDebugMode) return 'http://localhost:5150';
    return 'https://flexio.runasp.net';
  }

  /// Külső képeket a saját szerverünkön át töltjük (CORS fix Flutter weben).
  static String kep(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith(baseUrl)) return url;
    return '$baseUrl/api/kep?url=${Uri.encodeComponent(url)}';
  }
}
