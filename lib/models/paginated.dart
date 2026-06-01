/// Wraps Laravel's paginated list shape: { data, current_page, last_page, ... }
class Paginated<T> {
  final List<T> data;
  final int currentPage;
  final int lastPage;
  final int total;

  Paginated({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  bool get hasMore => currentPage < lastPage;

  factory Paginated.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) parse,
  ) =>
      Paginated<T>(
        data: (j['data'] as List? ?? [])
            .map((e) => parse(Map<String, dynamic>.from(e)))
            .toList(),
        currentPage: (j['current_page'] as num?)?.toInt() ?? 1,
        lastPage: (j['last_page'] as num?)?.toInt() ?? 1,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}
