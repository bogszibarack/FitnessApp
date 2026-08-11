/// Third-party integration credentials.
///
/// Set via `--dart-define=STRAVA_CLIENT_ID=...` and `STRAVA_CLIENT_SECRET=...`
/// at build time. When empty, Strava connect shows a "not configured" message.
class IntegrationsConfig {
  static const stravaClientId =
      String.fromEnvironment('STRAVA_CLIENT_ID', defaultValue: '');
  static const stravaClientSecret =
      String.fromEnvironment('STRAVA_CLIENT_SECRET', defaultValue: '');

  /// OAuth redirect captured by flutter_web_auth_2 (must match Strava app settings).
  static const stravaRedirectUri =
      String.fromEnvironment('STRAVA_REDIRECT_URI', defaultValue: 'flexio://strava/callback');

  static bool get stravaConfigured =>
      stravaClientId.isNotEmpty && stravaClientSecret.isNotEmpty;
}
