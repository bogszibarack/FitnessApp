import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart' show TargetPlatform;

/// Platform ellenorzes dart:io nelkul (weben a dart:io hibat dob).
bool get isAppleHealthPlatform =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
