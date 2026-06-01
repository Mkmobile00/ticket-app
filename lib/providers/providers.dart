import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/api/api_config.dart';
import '../core/api/api_service.dart';
import '../core/api/dio_client.dart';
import '../core/storage/city_store.dart';
import '../core/storage/token_store.dart';
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
        return null;
      }
      return apiError(res, 'Google sign-in failed.');
    } catch (e) {
      return 'Google sign-in failed: $e';
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
