import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';
import 'bookings_screen.dart';

final ticketProvider = FutureProvider.autoDispose.family<Booking, int>(
  (ref, id) => ref.read(apiProvider).booking(id),
);

class TicketScreen extends ConsumerStatefulWidget {
  final int bookingId;
  const TicketScreen({super.key, required this.bookingId});

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  final _qrKey = GlobalKey();
  bool _sharing = false;

  int get bookingId => widget.bookingId;

  Future<void> _cancel(Booking b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel booking?'),
        content: const Text('Your seats will be released. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancel booking', style: TextStyle(color: AppColors.seatBooked))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).cancelBooking(bookingId);
      ref.invalidate(ticketProvider(bookingId));
      ref.invalidate(bookingsProvider);
      if (mounted) showSnack(context, 'Booking cancelled.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  /// Render the QR (the boundary) to a PNG and open the share sheet, from which
  /// the user can save to gallery/files or send it on.
  Future<void> _shareQr(Booking b) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/buleto_ticket_${b.id}.png');
      await file.writeAsBytes(bytes);

      final seats = b.seats.map((s) => s.seat).join(', ');
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: 'My Buleto ticket — ${b.subject}\nBooking #${b.id} · Seats: $seats · ${rs(b.totalAmount)}',
        subject: 'Buleto Ticket #${b.id}',
      );
    } catch (e) {
      if (mounted) showSnack(context, 'Could not share ticket.', error: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(ticketProvider(bookingId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go('/bookings'),
        ),
        actions: [
          ticket.maybeWhen(
            data: (b) => (b.qrCode != null && b.qrCode!.isNotEmpty)
                ? IconButton(
                    tooltip: 'Share / Save',
                    icon: _sharing
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.ios_share),
                    onPressed: _sharing ? null : () => _shareQr(b),
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: ticket.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(ticketProvider(bookingId)), message: e.toString()),
        data: (b) => _content(b),
      ),
    );
  }

  Widget _content(Booking b) {
    final canCancel = b.isConfirmed || b.isPending;
    final hasQr = b.qrCode != null && b.qrCode!.isNotEmpty;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(b.subject, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('Booking #${b.id}', style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 20),
                _qr(b),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 8),
                _info('Status', b.status.toUpperCase()),
                _info('Seats', b.seats.map((s) => s.seat).join(', ')),
                if (b.seats.any((s) => s.tier != null))
                  _info('Tier', b.seats.map((s) => s.tier).whereType<String>().toSet().join(', ')),
                _info('Total paid', rs(b.totalAmount)),
                if (b.paymentMethod != null) _info('Payment', b.paymentMethod!.toUpperCase()),
                if (b.bookedAt != null) _info('Booked', b.bookedAt!.split('T').first),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (hasQr)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.surface2, minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.download_outlined),
            label: const Text('Download / Share QR'),
            onPressed: _sharing ? null : () => _shareQr(b),
          ),
        const SizedBox(height: 12),
        if (canCancel)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.seatBooked,
              side: const BorderSide(color: AppColors.seatBooked),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel booking'),
            onPressed: () => _cancel(b),
          ),
      ],
    );
  }

  Widget _qr(Booking b) {
    if (b.qrCode == null || b.qrCode!.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.hourglass_empty, color: AppColors.muted, size: 40),
            SizedBox(height: 8),
            Text('QR appears once payment is confirmed.', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }
    // RepaintBoundary so we can rasterise just the QR card for sharing/saving.
    return RepaintBoundary(
      key: _qrKey,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: b.qrCode!, size: 200, backgroundColor: Colors.white),
            const SizedBox(height: 8),
            Text('BULETO · #${b.id}', style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
