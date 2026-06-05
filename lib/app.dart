import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/push_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'providers/providers.dart';

class BuletoApp extends ConsumerStatefulWidget {
  const BuletoApp({super.key});

  @override
  ConsumerState<BuletoApp> createState() => _BuletoAppState();
}

class _BuletoAppState extends ConsumerState<BuletoApp> {
  @override
  void initState() {
    super.initState();
    // Record every received notification into the in-app inbox.
    PushService.onMessageReceived = (n) =>
        ref.read(notificationsProvider.notifier).add(n);

    // Route to the right place when a notification is tapped.
    PushService.onTap = (data) {
      final router = ref.read(routerProvider);
      final link = data['link']?.toString();
      if (link != null && link.startsWith('/')) {
        router.go(link);
      } else if (data['type'] == 'booking' || data['type'] == 'reminder') {
        router.go('/bookings');
      }
    };
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Buleto',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
