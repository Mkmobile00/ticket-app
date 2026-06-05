import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking.dart';
import '../../models/seat_map.dart';
import '../../providers/providers.dart';
import '../checkout/checkout_screen.dart';
import '../common/widgets.dart';

/// Arguments passed to the seat map (and onward to checkout).
class SeatArgs {
  final String type; // showtime | event | sport
  final int id;
  final String subject;
  final String? subtitle;
  const SeatArgs({required this.type, required this.id, required this.subject, this.subtitle});
}

class SeatMapScreen extends ConsumerStatefulWidget {
  final SeatArgs args;
  const SeatMapScreen({super.key, required this.args});

  @override
  ConsumerState<SeatMapScreen> createState() => _SeatMapScreenState();
}

class _SeatMapScreenState extends ConsumerState<SeatMapScreen> {
  SeatMap? _map;
  final Set<String> _selected = {};
  bool _loading = true;
  bool _reserving = false;
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
    _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool initial = false}) async {
    try {
      final map = await ref.read(apiProvider).seats(widget.args.type, widget.args.id);
      if (!mounted) return;
      setState(() {
        _map = map;
        // Pre-select seats the server says are already held by me.
        if (initial) {
          for (final r in map.rows) {
            for (final s in r.seats) {
              if (s.isSeat && s.status == 'mine') _selected.add(s.id);
            }
          }
        } else {
          // Drop any selection that someone else took since the last poll.
          final taken = <String>{};
          for (final r in map.rows) {
            for (final s in r.seats) {
              if (_selected.contains(s.id) && (s.status == 'booked' || s.status == 'locked')) {
                taken.add(s.id);
              }
            }
          }
          if (taken.isNotEmpty) {
            _selected.removeAll(taken);
            showSnack(context, 'Some seats were just taken and removed from your selection.', error: true);
          }
        }
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (initial) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  double _priceOf(String seatId) {
    for (final r in _map!.rows) {
      for (final s in r.seats) {
        if (s.id == seatId) return s.price ?? 0;
      }
    }
    return 0;
  }

  double get _total => _selected.fold(0, (sum, id) => sum + _priceOf(id));

  void _toggle(Seat s) {
    if (!s.isSeat || s.status == 'booked' || s.status == 'locked') return;
    setState(() {
      if (_selected.contains(s.id)) {
        _selected.remove(s.id);
      } else {
        if (_selected.length >= 10) {
          showSnack(context, 'You can select up to 10 seats.', error: true);
          return;
        }
        _selected.add(s.id);
      }
    });
  }

  Future<void> _proceed() async {
    if (_selected.isEmpty) return;

    // Guests can browse & pick seats; booking requires an account.
    if (ref.read(authProvider).status != AuthStatus.authenticated) {
      _poll?.cancel();
      showSnack(context, 'Please log in to book your seats.');
      await context.push('/login');
      if (!mounted) return;
      if (ref.read(authProvider).status != AuthStatus.authenticated) {
        // User backed out without logging in — resume the live seat map.
        _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
        _load();
        return;
      }
      // Logged in — fall through and reserve.
    }

    setState(() => _reserving = true);
    try {
      _poll?.cancel();
      final Booking booking = await ref.read(apiProvider).reserve(
            type: widget.args.type,
            id: widget.args.id,
            seats: _selected.toList(),
          );
      if (!mounted) return;
      setState(() => _reserving = false);
      context.push('/checkout', extra: CheckoutArgs(booking: booking, seatArgs: widget.args));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _reserving = false);
      showSnack(context, e.message, error: true);
      _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _reserving = false);
      showSnack(context, 'Could not reserve seats.', error: true);
      _poll = Timer.periodic(const Duration(seconds: 10), (_) => _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          _header(),
          Expanded(
            child: _loading
                ? const Loading()
                : _error != null
                    ? ErrorRetry(onRetry: () => _load(initial: true), message: _error!)
                    : _buildMap(),
          ),
          if (!_loading && _error == null && (_map?.rows.isNotEmpty ?? false)) _legend(),
        ]),
      ),
      bottomNavigationBar: _loading || _error != null ? null : _bottomBar(),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
      child: Row(children: [
        GestureDetector(
          onTap: () => context.pop(),
          child: Container(width: 40, height: 40, alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
            child: const Icon(Icons.arrow_back, size: 20, color: AppColors.text)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Select Seats', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
          if (widget.args.subtitle != null)
            Text(widget.args.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }

  Widget _buildMap() {
    final map = _map!;
    if (map.rows.isEmpty) {
      return const EmptyView(message: 'No seat layout configured for this show.', icon: Icons.event_seat_outlined);
    }

    // Price per tier name, and rows grouped by their tier (order preserved).
    final priceByTier = {for (final t in map.tiers) t.name: t.price};
    final groups = <String, List<SeatRow>>{};
    for (final r in map.rows) {
      (groups[r.tier ?? 'Seats'] ??= []).add(r);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(children: [
        const SizedBox(height: 8),
        _screen(),
        const SizedBox(height: 24),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final g in groups.entries) ..._tierGroup(g.key, priceByTier[g.key] ?? 0, g.value),
          ]),
        ),
      ]),
    );
  }

  List<Widget> _tierGroup(String name, double price, List<SeatRow> rows) {
    return [
      Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.text)),
          if (price > 0) ...[
            const SizedBox(width: 10),
            Text(rs(price).replaceAll('Rs ', '₹'), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.accent2)),
          ],
        ]),
      ),
      for (final r in rows) Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 16, child: Text(r.row, style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w700))),
          const SizedBox(width: 4),
          ...r.seats.map(_seatWidget),
        ]),
      ),
      const SizedBox(height: 22),
    ];
  }

  Widget _screen() {
    return Column(children: [
      Container(
        width: 280, height: 30,
        decoration: BoxDecoration(
          border: const Border(top: BorderSide(color: AppColors.accent, width: 3)),
          borderRadius: const BorderRadius.vertical(top: Radius.elliptical(280, 36)),
          boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .25), blurRadius: 22, spreadRadius: -6, offset: const Offset(0, -4))],
        ),
      ),
      const SizedBox(height: 8),
      const Text('SCREEN THIS WAY', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 3)),
    ]);
  }

  Widget _seatWidget(Seat s) {
    if (!s.isSeat) return const SizedBox(width: 16, height: 30);

    final selected = _selected.contains(s.id);
    final status = selected ? 'mine' : s.status;
    Color bg, fg, borderC;
    bool faded = false;
    switch (status) {
      case 'booked':
      case 'locked':
        bg = AppColors.surface2; fg = AppColors.muted; borderC = AppColors.line; faded = true;
        break;
      case 'mine':
        bg = AppColors.seatMine; fg = Colors.white; borderC = AppColors.seatMine;
        break;
      default:
        bg = AppColors.surface; fg = AppColors.accent2; borderC = AppColors.accent;
    }
    final label = s.id.split('-').last;
    return GestureDetector(
      onTap: faded ? null : () => _toggle(s),
      child: Container(
        width: 26, height: 26,
        margin: const EdgeInsets.all(2.5),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7), border: Border.all(color: borderC, width: 1.4)),
        child: Text(label, style: TextStyle(fontSize: 10, color: fg, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _legend() {
    Widget item(Color c, Color border, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 16, height: 16, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5), border: Border.all(color: border, width: 1.4))),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
        ]);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.line))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
        item(AppColors.surface, AppColors.accent, 'Available'),
        item(AppColors.seatMine, AppColors.seatMine, 'Selected'),
        item(AppColors.surface2, AppColors.line, 'Sold'),
      ]),
    );
  }

  Widget _bottomBar() {
    final chips = _selected.map((id) => id.replaceAll('-', '')).toList()..sort();
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_selected.length} SEAT${_selected.length == 1 ? '' : 'S'} · ${rs(_total).replaceAll('Rs ', '₹')}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .3)),
              if (chips.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: chips.take(6).map((c) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(6)),
                  child: Text(c, style: const TextStyle(color: AppColors.accent2, fontSize: 11.5, fontWeight: FontWeight.w800)),
                )).toList()),
              ],
            ]),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: (_selected.isEmpty || _reserving) ? null : _proceed,
            child: Container(
              height: 50, padding: const EdgeInsets.symmetric(horizontal: 26), alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _selected.isEmpty ? AppColors.surface2 : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _selected.isEmpty ? AppColors.line : AppColors.accent),
                boxShadow: _selected.isEmpty ? null : [BoxShadow(color: AppColors.accent.withValues(alpha: .18), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: _reserving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                  : Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('Proceed', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _selected.isEmpty ? AppColors.muted : AppColors.text)),
                      const SizedBox(width: 8),
                      Icon(Icons.arrow_forward, size: 18, color: _selected.isEmpty ? AppColors.muted : AppColors.text),
                    ]),
            ),
          ),
        ]),
      ),
    );
  }
}
