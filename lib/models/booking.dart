class Booking {
  final int id;
  final String status; // pending | confirmed | cancelled | refunded | completed
  final String subject;
  final int? showtimeId;
  final double totalAmount;
  final String? paymentMethod;
  final String? qrCode;
  final String? qrImage;
  final String? bookedAt;
  final List<BookingSeat> seats;

  Booking({
    required this.id,
    required this.status,
    required this.subject,
    this.showtimeId,
    required this.totalAmount,
    this.paymentMethod,
    this.qrCode,
    this.qrImage,
    this.bookedAt,
    this.seats = const [],
  });

  bool get isConfirmed => status == 'confirmed' || status == 'completed';
  bool get isPending => status == 'pending';

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as int,
        status: j['status'] ?? 'pending',
        subject: j['subject'] ?? 'Booking',
        showtimeId: j['showtime_id'] as int?,
        totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
        paymentMethod: j['payment_method'] as String?,
        qrCode: j['qr_code'] as String?,
        qrImage: j['qr_image'] as String?,
        bookedAt: j['booked_at'] as String?,
        seats: (j['seats'] as List? ?? [])
            .map((e) => BookingSeat.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}

class BookingSeat {
  final String seat;
  final String? tier;
  final double price;

  BookingSeat({required this.seat, this.tier, required this.price});

  factory BookingSeat.fromJson(Map<String, dynamic> j) => BookingSeat(
        seat: j['seat'] ?? '',
        tier: j['tier'] as String?,
        price: (j['price'] as num?)?.toDouble() ?? 0,
      );
}
