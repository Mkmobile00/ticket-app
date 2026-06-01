class PopcornItem {
  final int id;
  final String name;
  final String? description;
  final double price;
  final String? image;

  PopcornItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    this.image,
  });

  factory PopcornItem.fromJson(Map<String, dynamic> j) => PopcornItem(
        id: j['id'] as int,
        name: j['name'] ?? '',
        description: j['description'] as String?,
        price: (j['price'] as num?)?.toDouble() ?? 0,
        image: j['image'] as String?,
      );
}
