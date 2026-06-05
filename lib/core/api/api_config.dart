class ApiConfig {
  /// Base URL of the Buleto Laravel API.
  /// - Android emulator  -> http://10.0.2.2:8000/api/v1  (10.0.2.2 = host PC)
  /// - iOS simulator/web -> http://127.0.0.1:8000/api/v1
  /// - Real device       -> http://YOUR_PC_LAN_IP:8000/api/v1
  /// - Production         -> https://your-domain/api/v1
  ///
  /// USB device via `adb reverse tcp:8000 tcp:8000` -> phone localhost maps to this PC.
  /// (Wi‑Fi device: use this PC's LAN IP e.g. http://192.168.1.66:8000/api/v1)
  /// (Android emulator: http://10.0.2.2:8000/api/v1)
  static const String baseUrl = 'http://127.0.0.1:8000/api/v1';

  /// Google OAuth **Web client ID** (from Google Cloud / Firebase console).
  /// Required so `google_sign_in` returns an `id_token` the Laravel backend
  /// can verify at POST /auth/google. Leave empty to hide the Google button.
  /// e.g. '1234567890-abcdef.apps.googleusercontent.com'
  static const String googleServerClientId = '';

  static bool get googleEnabled => googleServerClientId.isNotEmpty;
}
