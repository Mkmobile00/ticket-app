/// Movie card used in lists/home, plus optional detail fields.
class Movie {
  final int id;
  final String title;
  final String slug;
  final String posterImage;
  final int? durationMinutes;
  final String? releaseDate;
  final double? userRating;
  final String? status;
  final List<String> genres;
  final List<String> languages;
  final List<String> formats;

  // Detail-only fields.
  final String? synopsis;
  final String? bannerImage;
  final String? trailerUrl;
  final List<MovieCastMember> cast;

  Movie({
    required this.id,
    required this.title,
    required this.slug,
    required this.posterImage,
    this.durationMinutes,
    this.releaseDate,
    this.userRating,
    this.status,
    this.genres = const [],
    this.languages = const [],
    this.formats = const [],
    this.synopsis,
    this.bannerImage,
    this.trailerUrl,
    this.cast = const [],
  });

  static List<String> _strList(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  factory Movie.fromJson(Map<String, dynamic> j) => Movie(
        id: j['id'] as int,
        title: j['title'] ?? '',
        slug: j['slug'] ?? '',
        posterImage: j['poster_image'] ?? '',
        durationMinutes: j['duration_minutes'] as int?,
        releaseDate: j['release_date'] as String?,
        userRating: (j['user_rating'] as num?)?.toDouble(),
        status: j['status'] as String?,
        genres: _strList(j['genres']),
        languages: _strList(j['languages']),
        formats: _strList(j['formats']),
        synopsis: j['synopsis'] as String?,
        bannerImage: j['banner_image'] as String?,
        trailerUrl: j['trailer_url'] as String?,
        cast: (j['cast'] as List?)
                ?.map((e) => MovieCastMember.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );
}

class MovieCastMember {
  final String name;
  final String? character;
  final String? role;

  MovieCastMember({required this.name, this.character, this.role});

  factory MovieCastMember.fromJson(Map<String, dynamic> j) => MovieCastMember(
        name: j['name'] ?? '',
        character: j['character'] as String?,
        role: j['role'] as String?,
      );
}
