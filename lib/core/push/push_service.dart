import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../models/app_notification.dart';

/// Required top-level entry point for messages received while the app is in
/// the background / terminated. The OS renders the tray entry for us.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Intentionally minimal — no Flutter UI is available here.
}

/// Thin wrapper around Firebase Cloud Messaging.
///
/// Everything is guarded so the app runs fine even before Firebase is set up:
/// if `Firebase.initializeApp()` fails (no google-services.json yet),
/// [available] stays false and every method is a safe no-op.
class PushService {
  static bool available = false;

  /// Set by the app to handle a notification tap (data payload).
  static void Function(Map<String, dynamic> data)? onTap;

  /// Set by the app to record a received notification into the in-app inbox.
  static void Function(AppNotification)? onMessageReceived;

  static void _record(RemoteMessage m) {
    final cb = onMessageReceived;
    if (cb == null) return;
    cb(AppNotification(
      id: m.messageId ?? '${DateTime.now().microsecondsSinceEpoch}',
      title: m.notification?.title ?? m.data['title']?.toString() ?? 'Notification',
      body: m.notification?.body ?? m.data['body']?.toString() ?? '',
      image: m.data['image']?.toString() ?? m.notification?.android?.imageUrl,
      link: m.data['link']?.toString(),
      type: m.data['type']?.toString() ?? 'general',
      receivedAt: DateTime.now(),
    ));
  }

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'buleto_default',
    'Notifications',
    description: 'Booking confirmations and showtime reminders',
    importance: Importance.high,
  );

  static String get platform => Platform.isIOS ? 'ios' : 'android';

  /// Call once at startup, before runApp. Never throws.
  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      available = true;
    } catch (e) {
      available = false;
      debugPrint('PushService: Firebase not configured ($e) — push disabled.');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // Local notifications, used to display messages while in the foreground.
    await _local.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload != null && onTap != null) {
          onTap!({'link': payload});
        }
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    // Foreground message → show a heads-up local notification (with image if present).
    FirebaseMessaging.onMessage.listen((message) async {
      final n = message.notification;
      if (n == null) return;
      _record(message);

      final imageUrl = message.data['image']?.toString() ?? n.android?.imageUrl;
      AndroidBitmap<Object>? bigPicture;
      StyleInformation? style;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final bytes = await _download(imageUrl);
        if (bytes != null) {
          bigPicture = ByteArrayAndroidBitmap(bytes);
          style = BigPictureStyleInformation(
            bigPicture,
            contentTitle: n.title,
            summaryText: n.body,
            hideExpandedLargeIcon: true,
          );
        }
      }

      _local.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            largeIcon: bigPicture,
            styleInformation: style,
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        payload: message.data['link']?.toString(),
      );
    });

    // App opened from a notification tap.
    FirebaseMessaging.instance.getInitialMessage().then((m) {
      if (m != null) {
        _record(m);
        onTap?.call(m.data);
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      _record(m);
      onTap?.call(m.data);
    });
  }

  /// Request permission (iOS / Android 13+) and return the FCM token, or null.
  static Future<String?> requestAndGetToken() async {
    if (!available) return null;
    try {
      await FirebaseMessaging.instance.requestPermission();
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      debugPrint('PushService: token error $e');
      return null;
    }
  }

  static Stream<String> get onTokenRefresh => available
      ? FirebaseMessaging.instance.onTokenRefresh
      : const Stream<String>.empty();

  /// Download image bytes for a big-picture notification. Returns null on failure.
  static Future<Uint8List?> _download(String url) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
      final req = await client.getUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) {
        client.close();
        return null;
      }
      final builder = BytesBuilder();
      await for (final chunk in res) {
        builder.add(chunk);
      }
      client.close();
      return builder.takeBytes();
    } catch (_) {
      return null;
    }
  }
}
