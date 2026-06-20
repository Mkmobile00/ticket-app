import 'package:dio/dio.dart';

import '../../models/booking.dart';
import '../../models/city.dart';
import '../../models/event.dart';
import '../../models/movie.dart';
import '../../models/paginated.dart';
import '../../models/popcorn.dart';
import '../../models/seat_map.dart';
import '../../models/showtime.dart';
import '../../models/sport.dart';
import 'dio_client.dart';

/// Thrown when the API returns an error status; carries a friendly message.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

/// Single typed gateway to every Buleto endpoint.
class ApiService {
  final Dio _dio;
  ApiService(this._dio);

  // ---- helpers ----
  bool _ok(Response r) => r.statusCode != null && r.statusCode! >= 200 && r.statusCode! < 300;

  Never _fail(Response r, [String fallback = 'Something went wrong']) =>
      throw ApiException(apiError(r, fallback), r.statusCode);

  Map<String, dynamic> _map(Response r) => Map<String, dynamic>.from(r.data as Map);

  // ---- Catalog ----
  Future<List<City>> cities() async {
    final r = await _dio.get('/cities');
    if (!_ok(r)) _fail(r);
    return (_map(r)['data'] as List).map((e) => City.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<List<Map<String, dynamic>>> options(String which) async {
    // which = genres | languages | formats
    final r = await _dio.get('/$which');
    if (!_ok(r)) _fail(r);
    return (_map(r)['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Paginated<Movie>> movies({String? search, String? genre, int? city, int page = 1}) async {
    final r = await _dio.get('/movies', queryParameters: {
      if (search != null && search.isNotEmpty) 'search': search,
      if (genre != null && genre.isNotEmpty) 'genre': genre,
      if (city != null) 'city': city,
      'page': page,
    });
    if (!_ok(r)) _fail(r);
    return Paginated.fromJson(_map(r), Movie.fromJson);
  }

  Future<Movie> movie(String slug) async {
    final r = await _dio.get('/movies/$slug');
    if (!_ok(r)) _fail(r, 'Movie not found');
    return Movie.fromJson(Map<String, dynamic>.from(_map(r)['data']));
  }

  Future<List<CinemaShowtimes>> showtimes(String slug, {int? city, String? date}) async {
    final r = await _dio.get('/movies/$slug/showtimes', queryParameters: {
      if (city != null) 'city': city,
      if (date != null) 'date': date,
    });
    if (!_ok(r)) _fail(r);
    return (_map(r)['data'] as List)
        .map((e) => CinemaShowtimes.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Paginated<Event>> events({int page = 1}) async {
    final r = await _dio.get('/events', queryParameters: {'page': page});
    if (!_ok(r)) _fail(r);
    return Paginated.fromJson(_map(r), Event.fromJson);
  }

  Future<Event> event(String slug) async {
    final r = await _dio.get('/events/$slug');
    if (!_ok(r)) _fail(r, 'Event not found');
    return Event.fromJson(Map<String, dynamic>.from(_map(r)['data']));
  }

  Future<Paginated<Sport>> sports({int page = 1}) async {
    final r = await _dio.get('/sports', queryParameters: {'page': page});
    if (!_ok(r)) _fail(r);
    return Paginated.fromJson(_map(r), Sport.fromJson);
  }

  Future<Sport> sport(String slug) async {
    final r = await _dio.get('/sports/$slug');
    if (!_ok(r)) _fail(r, 'Sport not found');
    return Sport.fromJson(Map<String, dynamic>.from(_map(r)['data']));
  }

  Future<SeatMap> seats(String type, int id) async {
    final r = await _dio.get('/seats/$type/$id');
    if (!_ok(r)) _fail(r, 'Could not load seats');
    return SeatMap.fromJson(_map(r));
  }

  // ---- Content ----
  Future<Map<String, dynamic>> home() async {
    final r = await _dio.get('/home');
    if (!_ok(r)) _fail(r, 'Failed to load home');
    return _map(r);
  }

  /// Dedicated mobile banners endpoint: [{id, title, image, link}].
  Future<List<Map<String, dynamic>>> banners() async {
    final r = await _dio.get('/banners');
    if (!_ok(r)) _fail(r);
    return (_map(r)['data'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> search(String q) async {
    final r = await _dio.get('/search', queryParameters: {'q': q});
    if (!_ok(r)) _fail(r);
    return _map(r);
  }

  Future<List<PopcornItem>> popcorn() async {
    final r = await _dio.get('/popcorn');
    if (!_ok(r)) _fail(r);
    return (_map(r)['data'] as List)
        .map((e) => PopcornItem.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, dynamic>> validatePromo(String code, double amount) async {
    final r = await _dio.post('/promo/validate', data: {'code': code, 'amount': amount});
    // Returns 200 (valid) or 422 (invalid) — caller reads `valid`.
    return _map(r);
  }

  Future<String> contact({required String name, required String email, String? subject, required String message}) async {
    final r = await _dio.post('/contact', data: {
      'name': name,
      'email': email,
      if (subject != null && subject.isNotEmpty) 'subject': subject,
      'message': message,
    });
    if (!_ok(r)) _fail(r);
    return _map(r)['message'] ?? 'Sent';
  }

  Future<String> newsletter(String email) async {
    final r = await _dio.post('/newsletter', data: {'email': email});
    if (!_ok(r)) _fail(r);
    return _map(r)['message'] ?? 'Subscribed';
  }

  // ---- Profile ----
  Future<Map<String, dynamic>> profile() async {
    final r = await _dio.get('/profile');
    if (!_ok(r)) _fail(r);
    return Map<String, dynamic>.from(_map(r)['data']);
  }

  Future<String> updateProfile({required String name, required String email, String? phone}) async {
    final r = await _dio.put('/profile', data: {
      'name': name,
      'email': email,
      if (phone != null) 'phone': phone,
    });
    if (!_ok(r)) _fail(r, 'Could not update profile');
    return _map(r)['message'] ?? 'Updated';
  }

  Future<String> changePassword({required String current, required String password}) async {
    final r = await _dio.put('/profile/password', data: {
      'current_password': current,
      'password': password,
      'password_confirmation': password,
    });
    if (!_ok(r)) _fail(r, 'Could not change password');
    return _map(r)['message'] ?? 'Password updated';
  }

  // ---- Email verification ----
  Future<String> sendEmailVerification() async {
    final r = await _dio.post('/email/verify/send');
    if (!_ok(r)) _fail(r);
    return _map(r)['message'] ?? 'Code sent';
  }

  Future<String> verifyEmail(String code) async {
    final r = await _dio.post('/email/verify', data: {'code': code});
    if (!_ok(r)) _fail(r, 'Invalid code');
    return _map(r)['message'] ?? 'Verified';
  }

  // ---- Password reset (identifier = email OR phone) ----
  Future<String> forgotPassword(String identifier) async {
    final r = await _dio.post('/password/forgot', data: {'identifier': identifier});
    if (!_ok(r)) _fail(r);
    return _map(r)['message'] ?? 'If that account exists, a code was sent.';
  }

  Future<String> resetPassword({required String identifier, required String code, required String password}) async {
    final r = await _dio.post('/password/reset', data: {
      'identifier': identifier,
      'code': code,
      'password': password,
      'password_confirmation': password,
    });
    if (!_ok(r)) _fail(r, 'Invalid or expired code');
    return _map(r)['message'] ?? 'Password reset';
  }

  // ---- Bookings ----
  Future<Paginated<Booking>> bookings({int page = 1}) async {
    final r = await _dio.get('/bookings', queryParameters: {'page': page});
    if (!_ok(r)) _fail(r);
    return Paginated.fromJson(_map(r), Booking.fromJson);
  }

  Future<Booking> booking(int id) async {
    final r = await _dio.get('/bookings/$id');
    if (!_ok(r)) _fail(r, 'Booking not found');
    return Booking.fromJson(Map<String, dynamic>.from(_map(r)['data']));
  }

  /// Reserve seats (5-min hold). Returns the pending booking.
  Future<Booking> reserve({required String type, required int id, required List<String> seats}) async {
    final r = await _dio.post('/bookings', data: {'type': type, 'id': id, 'seats': seats});
    if (!_ok(r)) _fail(r, 'Could not reserve seats');
    return Booking.fromJson(Map<String, dynamic>.from(_map(r)['booking']));
  }

  Future<Booking> setAddons(int bookingId, List<Map<String, int>> items) async {
    final r = await _dio.post('/bookings/$bookingId/addons', data: {'items': items});
    if (!_ok(r)) _fail(r, 'Could not update add-ons');
    return Booking.fromJson(Map<String, dynamic>.from(_map(r)['booking']));
  }

  Future<Booking> applyPromo(int bookingId, String code) async {
    final r = await _dio.post('/bookings/$bookingId/apply-promo', data: {'code': code});
    if (!_ok(r)) _fail(r, 'Invalid or expired promo code.');
    return Booking.fromJson(Map<String, dynamic>.from(_map(r)['booking']));
  }

  /// Pay. For card -> returns {confirmed:true, booking}.
  /// For esewa/khalti -> returns {confirmed:false, redirect, form}.
  Future<PaymentResult> pay(int bookingId, String method) async {
    final r = await _dio.post('/bookings/$bookingId/pay', data: {'method': method});
    if (!_ok(r)) _fail(r, 'Payment failed');
    final m = _map(r);
    if (m['requires_redirect'] == true) {
      return PaymentResult.redirect(
        gateway: m['gateway'] as String?,
        redirect: m['redirect'] as String?,
        form: m['form'] is Map ? Map<String, dynamic>.from(m['form']) : null,
      );
    }
    return PaymentResult.confirmed(Booking.fromJson(Map<String, dynamic>.from(m['booking'])));
  }

  Future<Booking?> verifyPayment(int bookingId, {String? pidx}) async {
    final r = await _dio.post('/bookings/$bookingId/verify-payment',
        data: {if (pidx != null) 'pidx': pidx});
    if (r.statusCode == 402) return null; // not paid yet
    if (!_ok(r)) _fail(r, 'Could not verify payment');
    return Booking.fromJson(Map<String, dynamic>.from(_map(r)['booking']));
  }

  // ---- Push notifications (FCM) ----
  Future<void> registerDevice(String token, {String? platform}) async {
    try {
      await _dio.post('/device-token', data: {
        'token': token,
        if (platform != null) 'platform': platform,
      });
    } catch (_) {/* best-effort */}
  }

  Future<void> removeDevice(String token) async {
    try {
      await _dio.delete('/device-token', data: {'token': token});
    } catch (_) {/* best-effort */}
  }

  Future<void> cancelBooking(int id) async {
    final r = await _dio.post('/bookings/$id/cancel');
    if (!_ok(r)) _fail(r, 'Could not cancel booking');
  }

  Future<void> releaseBooking(int id) async {
    try {
      await _dio.delete('/bookings/$id/release');
    } catch (_) {/* best-effort */}
  }
}

class PaymentResult {
  final bool confirmed;
  final Booking? booking;
  final String? gateway;
  final String? redirect;
  final Map<String, dynamic>? form;

  PaymentResult._({required this.confirmed, this.booking, this.gateway, this.redirect, this.form});

  factory PaymentResult.confirmed(Booking b) => PaymentResult._(confirmed: true, booking: b);
  factory PaymentResult.redirect({String? gateway, String? redirect, Map<String, dynamic>? form}) =>
      PaymentResult._(confirmed: false, gateway: gateway, redirect: redirect, form: form);
}
