import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/booking.dart';
import '../../models/popcorn.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';
import '../seats/seat_map_screen.dart';
import 'payment_webview_screen.dart';

class CheckoutArgs {
  final Booking booking;
  final SeatArgs seatArgs;
  const CheckoutArgs({required this.booking, required this.seatArgs});
}

class CheckoutScreen extends ConsumerStatefulWidget {
  final CheckoutArgs args;
  const CheckoutScreen({super.key, required this.args});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late Booking _booking;
  late ApiService _api;
  late Timer _timer;
  int _remaining = 300;
  bool _confirmed = false;
  bool _busy = false;

  // Add-ons.
  List<PopcornItem> _popcorn = [];
  final Map<int, int> _qty = {}; // popcorn_item_id -> qty
  Timer? _addonDebounce;
  bool _savingAddons = false;
  final _promoController = TextEditingController();
  String? _appliedPromo;

  @override
  void initState() {
    super.initState();
    _booking = widget.args.booking;
    _api = ref.read(apiProvider);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer.cancel();
        _onExpired();
      } else {
        setState(() => _remaining--);
      }
    });
    _loadPopcorn();
  }

  @override
  void dispose() {
    _timer.cancel();
    _addonDebounce?.cancel();
    _promoController.dispose();
    // Free the hold if the user left without paying.
    if (!_confirmed && _booking.isPending) {
      _api.releaseBooking(_booking.id);
    }
    super.dispose();
  }

  Future<void> _loadPopcorn() async {
    try {
      final items = await _api.popcorn();
      if (mounted) setState(() => _popcorn = items);
    } catch (_) {}
  }

  void _onExpired() {
    if (!mounted) return;
    _api.releaseBooking(_booking.id);
    showSnack(context, 'Your seat hold expired.', error: true);
    if (context.canPop()) context.pop();
  }

  String get _timeLabel {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Local snacks subtotal from the chosen quantities.
  double get _addonsTotal {
    double t = 0;
    for (final p in _popcorn) {
      t += (_qty[p.id] ?? 0) * p.price;
    }
    return t;
  }

  // total_amount from the server is VAT-inclusive (5%). Derive the ex-VAT
  // subtotal + the VAT portion for display; the payable IS total_amount.
  static const double _vatRate = 0.05;
  double get _subtotalExVat => double.parse((_booking.totalAmount / (1 + _vatRate)).toStringAsFixed(2));
  double get _vat => double.parse((_booking.totalAmount - _subtotalExVat).toStringAsFixed(2));
  double get _payable => _booking.totalAmount;

  /// Change a snack quantity and auto-sync the total (debounced).
  void _changeQty(int id, int delta) {
    setState(() => _qty[id] = ((_qty[id] ?? 0) + delta).clamp(0, 50));
    _addonDebounce?.cancel();
    _addonDebounce = Timer(const Duration(milliseconds: 500), _saveAddons);
  }

  Future<void> _saveAddons() async {
    if (_savingAddons) return;
    setState(() => _savingAddons = true);
    try {
      final items = _qty.entries
          .where((e) => e.value > 0)
          .map((e) => {'popcorn_item_id': e.key, 'quantity': e.value})
          .toList();
      final b = await _api.setAddons(_booking.id, items);
      if (!mounted) return;
      setState(() => _booking = b);
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _savingAddons = false);
    }
  }

  Future<void> _applyPromo() async {
    final code = _promoController.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      final b = await _api.applyPromo(_booking.id, code);
      if (!mounted) return;
      setState(() {
        _booking = b;
        _appliedPromo = code;
      });
      showSnack(context, 'Promo "$code" applied.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _choosePayment() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Choose payment method', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            _payTile('card', 'Credit / Debit Card', Icons.credit_card),
            _payTile('esewa', 'eSewa', Icons.account_balance_wallet_outlined),
            _payTile('khalti', 'Khalti', Icons.account_balance_wallet_outlined),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _payTile(String method, String label, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: () {
        Navigator.pop(context);
        _pay(method);
      },
    );
  }

  Future<void> _pay(String method) async {
    setState(() => _busy = true);
    try {
      final result = await _api.pay(_booking.id, method);
      if (!mounted) return;

      if (result.confirmed && result.booking != null) {
        _goToTicket(result.booking!);
        return;
      }

      // Off-site gateway -> open WebView, then verify + poll.
      setState(() => _busy = false);
      final paid = await context.push<bool>('/payment-webview', extra: PaymentWebViewArgs(
        bookingId: _booking.id,
        gateway: result.gateway ?? method,
        redirect: result.redirect,
        form: result.form,
      ));
      if (!mounted) return;
      if (paid == true) {
        await _verifyAndPoll();
      } else {
        showSnack(context, 'Payment was not completed.', error: true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, e.message, error: true);
      }
    }
  }

  Future<void> _verifyAndPoll() async {
    setState(() => _busy = true);
    try {
      Booking? b = await _api.verifyPayment(_booking.id);
      // Poll until confirmed (max ~10 tries).
      for (var i = 0; i < 10 && (b == null || !b.isConfirmed); i++) {
        await Future.delayed(const Duration(seconds: 2));
        b = await _api.booking(_booking.id);
      }
      if (!mounted) return;
      if (b != null && b.isConfirmed) {
        _goToTicket(b);
      } else {
        setState(() => _busy = false);
        showSnack(context, 'Payment is still pending. Check My Bookings shortly.', error: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showSnack(context, 'Could not verify payment.', error: true);
      }
    }
  }

  void _goToTicket(Booking b) {
    _confirmed = true;
    _timer.cancel();
    context.pushReplacement('/ticket/${b.id}');
  }

  @override
  Widget build(BuildContext context) {
    final warn = _remaining <= 60;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: (warn ? AppColors.seatBooked : AppColors.surface2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(_timeLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(),
          const SizedBox(height: 16),
          _popcornSection(),
          const SizedBox(height: 16),
          _promoSection(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total payable (incl. VAT)', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    Text(rs(_payable), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              SizedBox(
                width: 170,
                child: AccentButton(label: 'Pay now', loading: _busy, onPressed: _choosePayment),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_booking.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (widget.args.seatArgs.subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(widget.args.seatArgs.subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _booking.seats
                  .map((s) => TagChip('${s.seat}${s.tier != null ? ' · ${s.tier}' : ''}'))
                  .toList(),
            ),
            const SizedBox(height: 12),
            _row('Seats (${_booking.seats.length})',
                rs(_booking.seats.fold<double>(0, (a, s) => a + s.price))),
            if (_addonsTotal > 0) _row('Snacks', rs(_addonsTotal)),
            if (_appliedPromo != null) _row('Promo ($_appliedPromo)', 'applied'),
            const Divider(height: 20),
            _row('Subtotal', rs(_subtotalExVat)),
            _row('VAT (5%)', rs(_vat)),
            const SizedBox(height: 4),
            _row('Amount payable', rs(_payable), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 16 : 14);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style.copyWith(color: bold ? Colors.white : AppColors.text)), Text(value, style: style)],
      ),
    );
  }

  Widget _popcornSection() {
    if (_popcorn.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Add snacks', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                if (_savingAddons)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            for (final p in _popcorn) _popcornTile(p),
          ],
        ),
      ),
    );
  }

  Widget _popcornTile(PopcornItem p) {
    final qty = _qty[p.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (p.image != null) RoundedImage(url: p.image!, width: 44, height: 44, radius: 8),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(rs(p.price), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: qty == 0 ? null : () => _changeQty(p.id, -1),
          ),
          Text('$qty', style: const TextStyle(fontWeight: FontWeight.w700)),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.accent),
            onPressed: () => _changeQty(p.id, 1),
          ),
        ],
      ),
    );
  }

  Widget _promoSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _promoController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'Promo code'),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              height: 48,
              child: OutlinedButton(onPressed: _busy ? null : _applyPromo, child: const Text('Apply')),
            ),
          ],
        ),
      ),
    );
  }
}
