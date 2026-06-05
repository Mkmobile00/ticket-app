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
    final seats = b.seats.map((s) => s.seat).join(', ');
    final tier = b.seats.map((s) => s.tier).whereType<String>().toSet().join(', ');
    final code = 'BLT${b.id.toString().padLeft(6, '0')}';
    final date = b.bookedAt != null ? b.bookedAt!.split('T').first : '—';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        if (b.isConfirmed) ...[
          Center(child: Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.accent2, size: 38),
          )),
          const SizedBox(height: 16),
          const Text('Booking confirmed!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text('Your tickets are ready. Show the QR at the gate.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 13.5)),
          const SizedBox(height: 20),
        ],

        Container(
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line)),
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 56, height: 72, decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [Color(0xFF8d5a52), Color(0xFF5a3530)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(b.subject, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 8),
                if (tier.isNotEmpty || seats.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(999)),
                    child: Text('${tier.isNotEmpty ? '$tier · ' : ''}${b.seats.length} seat${b.seats.length == 1 ? '' : 's'}',
                        style: const TextStyle(color: AppColors.accent2, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
              ])),
            ]),
            const SizedBox(height: 16),
            const _Dashed(),
            const SizedBox(height: 16),
            Row(children: [Expanded(child: _kv('SEATS', seats.isEmpty ? '—' : seats)), Expanded(child: _kv('PAID', rs(b.totalAmount)))]),
            const SizedBox(height: 14),
            Row(children: [Expanded(child: _kv('DATE', date)), Expanded(child: _kv('PAYMENT', (b.paymentMethod ?? '—').toUpperCase()))]),
            const SizedBox(height: 18),
            if (hasQr) Center(child: _qr(b)),
            const SizedBox(height: 14),
            const _Dashed(),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BOOKING ID', style: TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: .5)),
                const SizedBox(height: 2),
                Text(code, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
              ]),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(999)),
                child: Text(b.status[0].toUpperCase() + b.status.substring(1), style: const TextStyle(color: AppColors.accent2, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ]),
          ]),
        ),

        const SizedBox(height: 20),
        Row(children: [
          if (hasQr)
            Expanded(child: GestureDetector(
              onTap: _sharing ? null : () => _shareQr(b),
              child: Container(height: 50, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.download_outlined, size: 18, color: AppColors.text), SizedBox(width: 8),
                  Text('Download', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                ])),
            )),
          if (hasQr) const SizedBox(width: 12),
          Expanded(child: AccentButton(label: 'My Bookings', onPressed: () => context.go('/bookings'))),
        ]),
        const SizedBox(height: 12),
        if (canCancel)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFE5484D), side: const BorderSide(color: Color(0xFFE5484D)), minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.cancel_outlined),
            label: const Text('Cancel booking'),
            onPressed: () => _cancel(b),
          ),
      ],
    );
  }

  Widget _kv(String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w700, letterSpacing: .5)),
        const SizedBox(height: 3),
        Text(v, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text)),
      ]);

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

}

class _Dashed extends StatelessWidget {
  const _Dashed();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final count = (c.maxWidth / 9).floor().clamp(1, 200);
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(count, (_) => Container(width: 5, height: 1.4, color: AppColors.line)),
      );
    });
  }
}
