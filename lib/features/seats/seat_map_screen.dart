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
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.args.subject, style: const TextStyle(fontSize: 16)),
            if (widget.args.subtitle != null)
              Text(widget.args.subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
      body: _loading
          ? const Loading()
          : _error != null
              ? ErrorRetry(onRetry: () => _load(initial: true), message: _error!)
              : _buildMap(),
      bottomNavigationBar: _loading || _error != null ? null : _bottomBar(),
    );
  }

  Widget _buildMap() {
    final map = _map!;
    if (map.rows.isEmpty) {
      return const EmptyView(message: 'No seat layout configured for this show.', icon: Icons.event_seat_outlined);
    }
    const seat = 36.0; // big, tappable seats with numbers; scroll for the rest

    return Column(
      children: [
        _legend(),
        Expanded(
          // Two-axis scrolling: vertical (rows) + horizontal (seats per row).
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Center(child: _screenBar()),
                    const SizedBox(height: 22),
                    for (final row in map.rows) _rowWidget(row, seat),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _screenBar() {
    return Column(
      children: [
        Container(
          width: 240,
          height: 6,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(40),
          ),
        ),
        const SizedBox(height: 4),
        const Text('SCREEN', style: TextStyle(color: AppColors.muted, fontSize: 11, letterSpacing: 4)),
      ],
    );
  }

  Widget _rowWidget(SeatRow row, double seat) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 22, child: Text(row.row, style: const TextStyle(color: AppColors.muted, fontSize: 13))),
          const SizedBox(width: 4),
          ...row.seats.map((s) => _seatWidget(s, seat)),
        ],
      ),
    );
  }

  Widget _seatWidget(Seat s, double size) {
    // Aisle and blocked both render as empty walking space (no box).
    if (!s.isSeat) {
      return SizedBox(width: size + 6, height: size + 6);
    }

    final selected = _selected.contains(s.id);
    Color color;
    if (selected) {
      color = AppColors.seatMine;
    } else {
      switch (s.status) {
        case 'booked':
          color = AppColors.seatBooked;
          break;
        case 'locked':
          color = AppColors.seatLocked;
          break;
        case 'mine':
          color = AppColors.seatMine;
          break;
        default:
          color = AppColors.seatAvailable;
      }
    }
    final label = s.id.replaceAll('-', ''); // e.g. "A1"
    return GestureDetector(
      onTap: () => _toggle(s),
      child: Container(
        width: size,
        height: size,
        margin: const EdgeInsets.all(3),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(7),
          border: selected ? Border.all(color: Colors.white, width: 1.5) : null,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _legend() {
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      color: AppColors.surface,
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: [
          item(AppColors.seatAvailable, 'Available'),
          item(AppColors.seatMine, 'Selected'),
          item(AppColors.seatLocked, 'On hold'),
          item(AppColors.seatBooked, 'Sold'),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${_selected.length} seat${_selected.length == 1 ? '' : 's'} · incl. 5% VAT',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(rs(_total * 1.05), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            SizedBox(
              width: 160,
              child: AccentButton(
                label: 'Proceed',
                loading: _reserving,
                onPressed: _selected.isEmpty ? null : _proceed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
