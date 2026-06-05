import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/api/api_config.dart';
import 'core/push/push_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast: a release build must never talk to the API over cleartext HTTP.
  if (kReleaseMode && !ApiConfig.isSecure) {
    throw StateError(
      'Refusing to start a release build with a non-HTTPS API base URL. '
      'Build with --dart-define=API_BASE_URL=https://your-domain/api/v1',
    );
  }

  await PushService.init(); // safe no-op until Firebase is configured
  runApp(const ProviderScope(child: BuletoApp()));
}
