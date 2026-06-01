/// Showtimes grouped by cinema (GET /movies/{slug}/showtimes).
class CinemaShowtimes {
  final int cinemaId;
  final String cinemaName;
  final String? city;
  final List<Showtime> showtimes;

  CinemaShowtimes({
    required this.cinemaId,
    required this.cinemaName,
    this.city,
    required this.showtimes,
  });

  factory CinemaShowtimes.fromJson(Map<String, dynamic> j) {
    final cinema = Map<String, dynamic>.from(j['cinema'] ?? {});
    return CinemaShowtimes(
      cinemaId: cinema['id'] as int? ?? 0,
      cinemaName: cinema['name'] ?? '',
      city: cinema['city'] as String?,
      showtimes: (j['showtimes'] as List? ?? [])
          .map((e) => Showtime.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class Showtime {
  final int id;
  final String? screen;
  final String? date;
  final String? time;
  final String? language;
  final String? format;
  final int? availableSeats;

  Showtime({
    required this.id,
    this.screen,
    this.date,
    this.time,
    this.language,
    this.format,
    this.availableSeats,
  });

  factory Showtime.fromJson(Map<String, dynamic> j) => Showtime(
        id: j['id'] as int,
        screen: j['screen'] as String?,
        date: j['date'] as String?,
        time: j['time'] as String?,
        language: j['language'] as String?,
        format: j['format'] as String?,
        availableSeats: j['available_seats'] as int?,
      );
}
