import 'package:flutter/foundation.dart';

class ApiConfig {
  // Runtime-ban módosítható felhasználónév (onboarding után frissül)
  static String _defaultUserName = 'Koko';
  static String get defaultUserName => _defaultUserName;
  static set defaultUserName(String value) {
    if (value.isNotEmpty) _defaultUserName = value;
  }

  /// Production backend (Render).
  static const String productionUrl = 'https://fitnessapp-fnfv.onrender.com';

  /// Webes debug: lokális backend (dotnet run). Telefonon / release: Render.
  static String get baseUrl {
    if (kDebugMode && kIsWeb) return 'http://localhost:5150';
    return productionUrl;
  }

  /// Külső képeket a saját szerverünkön át töltjük (CORS fix Flutter weben).
  static String kep(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith(baseUrl)) return url;
    return '$baseUrl/api/image?url=${Uri.encodeComponent(url)}';
  }

  /// Absolute URL for uploaded media (`/uploads/...`) or pass-through http(s).
  static String mediaUrl(String path) {
    if (path.isEmpty) return '';
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$baseUrl$path';
    return '$baseUrl/$path';
  }
}
