import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static const defaultUserName = 'Koko';

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:5150';
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5150';
    return 'http://localhost:5150';
  }
}
