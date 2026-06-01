import 'seat_map.dart';

class Sport {
  final int id;
  final String title;
  final String slug;
  final String? matchup;
  final String bannerImage;
  final String? date;
  final String? venue;
  final String? city;

  // Detail-only.
  final String? description;
  final String? startTime;
  final List<SeatTier> tiers;

  Sport({
    required this.id,
    required this.title,
    required this.slug,
    this.matchup,
    required this.bannerImage,
    this.date,
    this.venue,
    this.city,
    this.description,
    this.startTime,
    this.tiers = const [],
  });

  factory Sport.fromJson(Map<String, dynamic> j) => Sport(
        id: j['id'] as int,
        title: j['title'] ?? '',
        slug: j['slug'] ?? '',
        matchup: j['matchup'] as String?,
        bannerImage: j['banner_image'] ?? '',
        date: j['date'] as String?,
        venue: j['venue'] as String?,
        city: j['city'] as String?,
        description: j['description'] as String?,
        startTime: j['start_time'] as String?,
        tiers: (j['tiers'] as List?)
                ?.map((e) => SeatTier.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );
}
