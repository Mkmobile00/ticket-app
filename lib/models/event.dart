import 'seat_map.dart';

class Event {
  final int id;
  final String title;
  final String slug;
  final String bannerImage;
  final String? date;
  final String? venue;
  final String? organizer;

  // Detail-only.
  final String? description;
  final String? startTime;
  final List<SeatTier> tiers;
  final List<Speaker> speakers;

  Event({
    required this.id,
    required this.title,
    required this.slug,
    required this.bannerImage,
    this.date,
    this.venue,
    this.organizer,
    this.description,
    this.startTime,
    this.tiers = const [],
    this.speakers = const [],
  });

  factory Event.fromJson(Map<String, dynamic> j) => Event(
        id: j['id'] as int,
        title: j['title'] ?? '',
        slug: j['slug'] ?? '',
        bannerImage: j['banner_image'] ?? '',
        date: j['date'] as String?,
        venue: j['venue'] as String?,
        organizer: j['organizer'] as String?,
        description: j['description'] as String?,
        startTime: j['start_time'] as String?,
        tiers: (j['tiers'] as List?)
                ?.map((e) => SeatTier.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
        speakers: (j['speakers'] as List?)
                ?.map((e) => Speaker.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            const [],
      );
}

class Speaker {
  final String name;
  final String? designation;
  final String? photo;
  final String? about;

  Speaker({required this.name, this.designation, this.photo, this.about});

  factory Speaker.fromJson(Map<String, dynamic> j) => Speaker(
        name: j['name'] ?? '',
        designation: j['designation'] as String?,
        photo: j['photo'] as String?,
        about: j['about'] as String?,
      );
}
