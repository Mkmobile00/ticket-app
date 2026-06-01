class City {
  final int id;
  final String name;
  final String slug;
  final String? icon;

  City({required this.id, required this.name, required this.slug, this.icon});

  factory City.fromJson(Map<String, dynamic> j) => City(
        id: j['id'] as int,
        name: j['name'] ?? '',
        slug: j['slug'] ?? '',
        icon: j['icon'] as String?,
      );
}
