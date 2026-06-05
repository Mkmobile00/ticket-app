import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/api/api_config.dart';
import '../core/api/api_service.dart';
import '../core/api/dio_client.dart';
import '../core/push/push_service.dart';
import '../core/storage/city_store.dart';
import '../core/storage/notification_store.dart';
import '../core/storage/token_store.dart';
import '../models/app_notification.dart';
import '../models/city.dart';
import '../models/user.dart';

/// Global navigator key so the Dio 401 handler can route to login.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final dioProvider = Provider<Dio>((ref) {
  final store = ref.read(tokenStoreProvider);
  return createDio(store, () {
    // On 401: clear session.
    ref.read(authProvider.notifier).forceLogout();
  });
});

/// Typed gateway to the Buleto API.
final apiProvider = Provider<ApiService>((ref) => ApiService(ref.read(dioProvider)));

/// Persists the chosen city across launches.
final cityStoreProvider = Provider<CityStore>((ref) => CityStore());

/// The city the user is browsing (null = all cities).
final selectedCityProvider = StateProvider<City?>((ref) => null);

/// In-app inbox of received push notifications (persisted locally).
final notificationStoreProvider = Provider<NotificationStore>((ref) => NotificationStore());

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, List<AppNotification>>(
        (ref) => NotificationsNotifier(ref.read(notificationStoreProvider))..load());

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  final NotificationStore _store;
  NotificationsNotifier(this._store) : super(const []);

  Future<void> load() async {
    state = await _store.all();
  }

  Future<void> add(AppNotification n) async {
    // De-dupe by id (the same message can arrive foreground + on tap).
    if (state.any((e) => e.id == n.id)) return;
    state = [n, ...state];
    await _store.save(state);
  }

  Future<void> markAllRead() async {
    state = [for (final n in state) n.copyWith(read: true)];
    await _store.save(state);
  }

  Future<void> clear() async {
    state = const [];
    await _store.save(state);
  }

  int get unread => state.where((n) => !n.read).length;
}

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  const AuthState({this.status = AuthStatus.unknown, this.user});

  AuthState copyWith({AuthStatus? status, User? user}) =>
      AuthState(status: status ?? this.status, user: user ?? this.user);
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) => AuthNotifier(ref));

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  AuthNotifier(this.ref) : super(const AuthState());

  Dio get _dio => ref.read(dioProvider);
  TokenStore get _store => ref.read(tokenStoreProvider);

  /// Last FCM token we registered, so we can unregister it on logout.
  String? _pushToken;
  bool _pushRefreshHooked = false;

  /// Register this device's FCM token with the backend (best-effort).
  Future<void> _syncPushToken() async {
    final token = await PushService.requestAndGetToken();
    if (token == null) return;
    _pushToken = token;
    await ref.read(apiProvider).registerDevice(token, platform: PushService.platform);

    // Re-register if FCM rotates the token while signed in.
    if (!_pushRefreshHooked) {
      _pushRefreshHooked = true;
      PushService.onTokenRefresh.listen((t) {
        if (state.status == AuthStatus.authenticated) {
          _pushToken = t;
          ref.read(apiProvider).registerDevice(t, platform: PushService.platform);
        }
      });
    }
  }

  /// On app start: if a token exists, fetch the user.
  Future<void> bootstrap() async {
    final token = await _store.read();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final res = await _dio.get('/me');
      if (res.statusCode == 200) {
        state = AuthState(status: AuthStatus.authenticated, user: User.fromJson(res.data['user']));
        unawaited(_syncPushToken());
        return;
      }
    } catch (_) {}
    await _store.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Returns null on success, or an error message.
  Future<String?> login(String email, String password) async {
    final res = await _dio.post('/login', data: {'email': email, 'password': password});
    if (res.statusCode == 200 && res.data['token'] != null) {
      await _store.write(res.data['token']);
      state = AuthState(status: AuthStatus.authenticated, user: User.fromJson(res.data['user']));
      unawaited(_syncPushToken());
      return null;
    }
    return apiError(res, 'Invalid credentials.');
  }

  Future<String?> register(String name, String email, String password, String? phone) async {
    final res = await _dio.post('/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'password_confirmation': password,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    if ((res.statusCode == 201 || res.statusCode == 200) && res.data['token'] != null) {
      await _store.write(res.data['token']);
      state = AuthState(status: AuthStatus.authenticated, user: User.fromJson(res.data['user']));
      unawaited(_syncPushToken());
      return null;
    }
    return apiError(res, 'Registration failed.');
  }

  /// Sign in with Google: get an id_token from the plugin, exchange it at
  /// POST /auth/google for a Sanctum token. Returns null on success.
  Future<String?> googleLogin() async {
    if (!ApiConfig.googleEnabled) {
      return 'Google sign-in is not configured. Set googleServerClientId in api_config.dart.';
    }
    try {
      final google = GoogleSignIn(
        scopes: const ['email'],
        serverClientId: ApiConfig.googleServerClientId,
      );
      await google.signOut(); // force account chooser
      final account = await google.signIn();
      if (account == null) return null; // user cancelled
      final gAuth = await account.authentication;
      final idToken = gAuth.idToken;
      if (idToken == null) return 'Could not obtain Google token.';

      final res = await _dio.post('/auth/google', data: {'id_token': idToken});
      if (res.statusCode == 200 && res.data['token'] != null) {
        await _store.write(res.data['token']);
        state = AuthState(status: AuthStatus.authenticated, user: User.fromJson(res.data['user']));
        unawaited(_syncPushToken());
        return null;
      }
      return apiError(res, 'Google sign-in failed.');
    } catch (e, st) {
      // Don't surface raw exception/SDK internals to the user.
      if (kDebugMode) debugPrint('Google sign-in failed: $e\n$st');
      return 'Google sign-in failed. Please try again.';
    }
  }

  /// Re-fetch the current user (after a profile/email update).
  Future<void> refresh() async {
    try {
      final res = await _dio.get('/me');
      if (res.statusCode == 200 && res.data['user'] != null) {
        state = state.copyWith(status: AuthStatus.authenticated, user: User.fromJson(res.data['user']));
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    // Stop pushes to this device first.
    if (_pushToken != null) {
      try {
        await ref.read(apiProvider).removeDevice(_pushToken!);
      } catch (_) {}
      _pushToken = null;
    }
    try {
      await _dio.post('/logout');
    } catch (_) {}
    await forceLogout();
  }

  Future<void> forceLogout() async {
    await _store.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
