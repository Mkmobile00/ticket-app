/// Seat map response (GET /seats/{type}/{id}).
class SeatMap {
  final String context;
  final List<SeatTier> tiers;
  final List<SeatRow> rows;
  final int lockTtl;

  SeatMap({
    required this.context,
    required this.tiers,
    required this.rows,
    required this.lockTtl,
  });

  factory SeatMap.fromJson(Map<String, dynamic> j) => SeatMap(
        context: j['context'] ?? '',
        tiers: (j['tiers'] as List? ?? [])
            .map((e) => SeatTier.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        rows: (j['rows'] as List? ?? [])
            .map((e) => SeatRow.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        lockTtl: (j['lock_ttl'] as num?)?.toInt() ?? 300,
      );
}

class SeatTier {
  final int? id;
  final String name;
  final double price;
  final List<String> rows;

  SeatTier({this.id, required this.name, required this.price, this.rows = const []});

  factory SeatTier.fromJson(Map<String, dynamic> j) => SeatTier(
        id: j['id'] as int?,
        name: j['name'] ?? '',
        price: (j['price'] as num?)?.toDouble() ?? 0,
        rows: (j['rows'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class SeatRow {
  final String row;
  final String? tier;
  final List<Seat> seats;

  SeatRow({required this.row, this.tier, required this.seats});

  factory SeatRow.fromJson(Map<String, dynamic> j) => SeatRow(
        row: j['row'] ?? '',
        tier: j['tier'] as String?,
        seats: (j['seats'] as List? ?? [])
            .map((e) => Seat.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

/// type ∈ seat | aisle | blocked.  status ∈ available | booked | locked | mine
class Seat {
  final String type;
  final String id;
  final String status;
  final String? tier;
  final double? price;

  Seat({this.type = 'seat', required this.id, required this.status, this.tier, this.price});

  bool get isSeat => type == 'seat';
  bool get isAisle => type == 'aisle';
  bool get isBlocked => type == 'blocked';

  factory Seat.fromJson(Map<String, dynamic> j) => Seat(
        type: j['type'] as String? ?? 'seat',
        id: j['id'] ?? '',
        status: j['status'] ?? 'available',
        tier: j['tier'] as String?,
        price: (j['price'] as num?)?.toDouble(),
      );
}
