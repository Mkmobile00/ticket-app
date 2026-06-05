class ApiConfig {
  /// Base URL of the Buleto Laravel API, injected at build time so a release
  /// build always points at the real HTTPS endpoint and the dev URL never ships:
  ///
  ///   flutter run   --dart-define=API_BASE_URL=http://192.168.1.78:8000/api/v1   (real device on LAN)
  ///   flutter build --dart-define=API_BASE_URL=https://api.your-domain/api/v1     (production)
  ///
  /// Reference hosts:
  /// - Android emulator  -> http://10.0.2.2:8000/api/v1  (10.0.2.2 = host PC)
  /// - iOS simulator/web -> http://127.0.0.1:8000/api/v1
  /// - USB device        -> `adb reverse tcp:8000 tcp:8000` then 127.0.0.1
  /// - Wi-Fi device      -> this PC's LAN IP, e.g. http://192.168.1.78:8000/api/v1
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000/api/v1', // dev default only
  );

  /// True when the API is reached over TLS. A release build must be secure.
  static bool get isSecure => baseUrl.startsWith('https://');

  /// Google OAuth **Web client ID** (from Google Cloud / Firebase console).
  /// Required so `google_sign_in` returns an `id_token` the Laravel backend
  /// can verify at POST /auth/google. Leave empty to hide the Google button.
  /// Inject with --dart-define=GOOGLE_SERVER_CLIENT_ID=... so it isn't hardcoded.
  static const String googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  static bool get googleEnabled => googleServerClientId.isNotEmpty;
}
