import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/booking.dart';
import '../../models/paginated.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';

final bookingsProvider = FutureProvider.autoDispose<Paginated<Booking>>(
  (ref) => ref.read(apiProvider).bookings(),
);

const _thumbs = [
  [Color(0xFF8d5a52), Color(0xFF5a3530)],
  [Color(0xFF3f6f5e), Color(0xFF274b3f)],
  [Color(0xFF4a5a8d), Color(0xFF2f3a66)],
  [Color(0xFF7a4f86), Color(0xFF4f2f5a)],
];

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});
  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  bool _past = false;

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingsProvider);
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 16, 6),
              child: Row(children: [
                const Text('My Bookings', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.4, color: AppColors.text)),
                const Spacer(),
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
                  child: const Icon(Icons.search, size: 20, color: AppColors.text),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
              child: Row(children: [
                _tab('Upcoming', !_past, () => setState(() => _past = false)),
                const SizedBox(width: 22),
                _tab('Past', _past, () => setState(() => _past = true)),
              ]),
            ),
            const Divider(height: 1),
            Expanded(
              child: bookings.when(
                loading: () => const Loading(),
                error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(bookingsProvider), message: e.toString()),
                data: (page) {
                  final items = page.data.where((b) {
                    final isPast = b.status == 'completed' || b.status == 'cancelled' || b.status == 'refunded';
                    return _past ? isPast : !isPast;
                  }).toList();
                  if (items.isEmpty) {
                    return EmptyView(message: _past ? 'No past bookings.' : 'No upcoming bookings.\nBook your first ticket!', icon: Icons.confirmation_number_outlined);
                  }
                  return RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: () async => ref.invalidate(bookingsProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _BookingCard(booking: items[i], tone: i),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool active, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: active ? AppColors.text : AppColors.muted)),
          const SizedBox(height: 6),
          Container(height: 3, width: 28, decoration: BoxDecoration(
            color: active ? AppColors.accent : Colors.transparent, borderRadius: BorderRadius.circular(3))),
        ]),
      );
}

class _BookingCard extends StatelessWidget {
  final Booking booking;
  final int tone;
  const _BookingCard({required this.booking, required this.tone});

  (Color, Color) get _badge {
    switch (booking.status) {
      case 'confirmed':
        return (AppColors.accent2, AppColors.accentSoft);
      case 'pending':
        return (const Color(0xFF8a6d1f), const Color(0xFFFBF1D6));
      case 'completed':
        return (AppColors.muted, AppColors.surface2);
      default:
        return (const Color(0xFFE5484D), const Color(0x1AE5484D));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _badge;
    final when = booking.bookedAt != null
        ? (() { try { return DateFormat('EEE, d MMM · HH:mm').format(DateTime.parse(booking.bookedAt!)); } catch (_) { return ''; } })()
        : '';
    final pair = _thumbs[tone % _thumbs.length];
    final seats = booking.seats.map((s) => s.seat).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 56, height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: pair, begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(booking.subject, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
                    child: Text(booking.status[0].toUpperCase() + booking.status.substring(1),
                        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 8),
                if (when.isNotEmpty)
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.accent),
                    const SizedBox(width: 7),
                    Text(when, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  ]),
              ]),
            ),
          ]),
        ),
        const Divider(height: 1, indent: 14, endIndent: 14),
        InkWell(
          onTap: () => context.push('/ticket/${booking.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Row(children: [
              Expanded(child: Text(
                seats.isEmpty ? rs(booking.totalAmount) : 'Seats $seats',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.muted, fontWeight: FontWeight.w600))),
              const Text('View ticket', style: TextStyle(color: AppColors.accent2, fontWeight: FontWeight.w800, fontSize: 13.5)),
              const Icon(Icons.chevron_right, size: 18, color: AppColors.accent2),
            ]),
          ),
        ),
      ]),
    );
  }
}
