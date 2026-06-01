import 'package:dio/dio.dart';

import '../storage/token_store.dart';
import 'api_config.dart';

/// Builds a Dio client that injects the Bearer token and reports 401s.
Dio createDio(TokenStore store, void Function() onUnauthorized) {
  final dio = Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    headers: {'Accept': 'application/json'},
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 20),
    // Don't throw on 4xx so we can read validation messages.
    validateStatus: (s) => s != null && s < 500,
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await store.read();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    },
    onResponse: (response, handler) {
      if (response.statusCode == 401) onUnauthorized();
      handler.next(response);
    },
  ));

  return dio;
}

/// Extracts a human message from a Laravel JSON error response.
String apiError(Response? res, [String fallback = 'Something went wrong']) {
  final data = res?.data;
  if (data is Map) {
    if (data['errors'] is Map && (data['errors'] as Map).isNotEmpty) {
      final first = (data['errors'] as Map).values.first;
      if (first is List && first.isNotEmpty) return first.first.toString();
    }
    if (data['message'] is String) return data['message'];
  }
  return fallback;
}
