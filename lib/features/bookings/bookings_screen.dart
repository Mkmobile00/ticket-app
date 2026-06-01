import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/booking.dart';
import '../../models/paginated.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';

final bookingsProvider = FutureProvider.autoDispose<Paginated<Booking>>(
  (ref) => ref.read(apiProvider).bookings(),
);

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Bookings')),
      body: bookings.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(bookingsProvider), message: e.toString()),
        data: (page) {
          if (page.data.isEmpty) {
            return const EmptyView(message: 'No bookings yet.\nBook your first ticket!', icon: Icons.confirmation_number_outlined);
          }
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async => ref.invalidate(bookingsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: page.data.length,
              itemBuilder: (_, i) => _BookingCard(booking: page.data[i]),
            ),
          );
        },
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  const _BookingCard({required this.booking});

  Color get _statusColor {
    switch (booking.status) {
      case 'confirmed':
      case 'completed':
        return AppColors.seatMine;
      case 'pending':
        return AppColors.seatLocked;
      default:
        return AppColors.seatBooked;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/ticket/${booking.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 56,
                decoration: BoxDecoration(color: _statusColor, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(
                      '${booking.seats.length} seat${booking.seats.length == 1 ? '' : 's'} · ${rs(booking.totalAmount)}',
                      style: const TextStyle(color: AppColors.muted, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _statusColor.withValues(alpha: .15), borderRadius: BorderRadius.circular(6)),
                      child: Text(booking.status.toUpperCase(), style: TextStyle(color: _statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
