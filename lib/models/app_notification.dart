/// A push notification the app has received, persisted locally so the user
/// can see a history in the in-app notifications list.
class AppNotification {
  final String id;
  final String title;
  final String body;
  final String? image;
  final String? link;
  final String type;
  final DateTime receivedAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.image,
    this.link,
    this.type = 'general',
    required this.receivedAt,
    this.read = false,
  });

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        title: title,
        body: body,
        image: image,
        link: link,
        type: type,
        receivedAt: receivedAt,
        read: read ?? this.read,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'image': image,
        'link': link,
        'type': type,
        'receivedAt': receivedAt.toIso8601String(),
        'read': read,
      };

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id']?.toString() ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        image: j['image'],
        link: j['link'],
        type: j['type'] ?? 'general',
        receivedAt: DateTime.tryParse(j['receivedAt'] ?? '') ?? DateTime.now(),
        read: j['read'] == true,
      );
}
