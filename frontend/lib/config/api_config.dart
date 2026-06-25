import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  // Runtime-ban módosítható felhasználónév (onboarding után frissül)
  static String _defaultUserName = 'Koko';
  static String get defaultUserName => _defaultUserName;
  static set defaultUserName(String value) {
    if (value.isNotEmpty) _defaultUserName = value;
  }

  // A Windows gép helyi IP-je (ahol a .NET backend fut).
  static const _backendIp = '192.168.1.141';
  static const _backendPort = '5150';
  static const _backendUrl = 'http://$_backendIp:$_backendPort';

  static String get baseUrl {
    if (kIsWeb) return _backendUrl;
    if (Platform.isAndroid) return 'http://10.0.2.2:$_backendPort';
    return _backendUrl;
  }

  /// Külső képeket a saját szerverünkön át töltjük (CORS fix Flutter weben).
  static String kep(String url) {
    if (url.isEmpty) return url;
    if (url.startsWith(baseUrl)) return url;
    return '$baseUrl/api/kep?url=${Uri.encodeComponent(url)}';
  }
}
