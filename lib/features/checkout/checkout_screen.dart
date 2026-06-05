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

const _ink2 = Color(0xFF46535F);

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
  String _method = 'card';

  List<PopcornItem> _popcorn = [];
  final Map<int, int> _qty = {};
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

  double get _addonsTotal {
    double t = 0;
    for (final p in _popcorn) {
      t += (_qty[p.id] ?? 0) * p.price;
    }
    return t;
  }

  static const double _vatRate = 0.05;
  double get _subtotalExVat => double.parse((_booking.totalAmount / (1 + _vatRate)).toStringAsFixed(2));
  double get _vat => double.parse((_booking.totalAmount - _subtotalExVat).toStringAsFixed(2));
  double get _payable => _booking.totalAmount;

  void _changeQty(int id, int delta) {
    setState(() => _qty[id] = ((_qty[id] ?? 0) + delta).clamp(0, 50));
    _addonDebounce?.cancel();
    _addonDebounce = Timer(const Duration(milliseconds: 500), _saveAddons);
  }

  Future<void> _saveAddons() async {
    if (_savingAddons) return;
    setState(() => _savingAddons = true);
    try {
      final items = _qty.entries.where((e) => e.value > 0)
          .map((e) => {'popcorn_item_id': e.key, 'quantity': e.value}).toList();
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
      setState(() { _booking = b; _appliedPromo = code; });
      showSnack(context, 'Promo "$code" applied.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      setState(() => _busy = false);
      final paid = await context.push<bool>('/payment-webview', extra: PaymentWebViewArgs(
        bookingId: _booking.id, gateway: result.gateway ?? method, redirect: result.redirect, form: result.form,
      ));
      if (!mounted) return;
      if (paid == true) {
        await _verifyAndPoll();
      } else {
        showSnack(context, 'Payment was not completed.', error: true);
      }
    } on ApiException catch (e) {
      if (mounted) { setState(() => _busy = false); showSnack(context, e.message, error: true); }
    }
  }

  Future<void> _verifyAndPoll() async {
    setState(() => _busy = true);
    try {
      Booking? b = await _api.verifyPayment(_booking.id);
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
      if (mounted) { setState(() => _busy = false); showSnack(context, 'Could not verify payment.', error: true); }
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
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 16, 8),
            child: Row(children: [
              _circleBack(),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Checkout', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                Text('Review & pay', style: TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w500)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: warn ? const Color(0x1AE5484D) : AppColors.surface2, borderRadius: BorderRadius.circular(999)),
                child: Row(children: [
                  Icon(Icons.timer_outlined, size: 15, color: warn ? const Color(0xFFE5484D) : _ink2),
                  const SizedBox(width: 6),
                  Text(_timeLabel, style: TextStyle(fontWeight: FontWeight.w800, color: warn ? const Color(0xFFE5484D) : _ink2)),
                ]),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
              children: [
                _summaryCard(),
                const SizedBox(height: 20),
                _sectionLabel('PRICE DETAILS'),
                _priceDetails(),
                const SizedBox(height: 14),
                _promoSection(),
                if (_popcorn.isNotEmpty) ...[const SizedBox(height: 20), _sectionLabel('ADD SNACKS'), _popcornCard()],
                const SizedBox(height: 20),
                _sectionLabel('PAYMENT METHOD'),
                _paymentSection(),
              ],
            ),
          ),
        ]),
      ),
      bottomNavigationBar: _payBar(),
    );
  }

  Widget _circleBack() => GestureDetector(
        onTap: () => context.pop(),
        child: Container(width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
          child: const Icon(Icons.arrow_back, size: 20, color: AppColors.text)),
      );

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6, color: AppColors.muted)),
      );

  Widget _card({required Widget child}) => Container(
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
        child: child,
      );

  Widget _summaryCard() {
    return _card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 56, height: 72, decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(colors: [Color(0xFF8d5a52), Color(0xFF5a3530)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_booking.subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.text)),
          if (widget.args.seatArgs.subtitle != null) ...[
            const SizedBox(height: 6),
            Text(widget.args.seatArgs.subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, height: 1.4)),
          ],
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: _booking.seats.map((s) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(6)),
            child: Text('${s.seat}${s.tier != null ? ' · ${s.tier}' : ''}', style: const TextStyle(color: AppColors.accent2, fontSize: 11, fontWeight: FontWeight.w800)),
          )).toList()),
        ])),
      ]),
    ));
  }

  Widget _priceDetails() {
    final tickets = _booking.seats.fold<double>(0, (a, s) => a + s.price);
    return _card(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(children: [
        _row('Tickets (${_booking.seats.length})', rs(tickets)),
        if (_addonsTotal > 0) _divRow('Snacks', rs(_addonsTotal)),
        if (_appliedPromo != null) _divRow('Promo ($_appliedPromo)', 'applied', accent: true),
        _divRow('GST (5%)', rs(_vat)),
        _divRow('Total payable', rs(_payable), bold: true),
      ]),
    ));
  }

  Widget _row(String label, String value, {bool bold = false, bool accent = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, fontSize: bold ? 16 : 14, color: AppColors.text)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w700, fontSize: bold ? 16 : 14, color: bold || accent ? AppColors.accent2 : AppColors.text)),
        ]),
      );

  Widget _divRow(String label, String value, {bool bold = false, bool accent = false}) => Column(children: [
        const Divider(height: 1),
        _row(label, value, bold: bold, accent: accent),
      ]);

  Widget _promoSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withValues(alpha: .4)),
      ),
      child: Row(children: [
        const Icon(Icons.local_offer_outlined, size: 18, color: AppColors.accent2),
        const SizedBox(width: 10),
        Expanded(child: TextField(
          controller: _promoController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            isDense: true, filled: false, border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
            hintText: 'Apply promo code', contentPadding: EdgeInsets.symmetric(vertical: 12),
          ),
        )),
        GestureDetector(onTap: _busy ? null : _applyPromo,
          child: const Padding(padding: EdgeInsets.all(8), child: Text('Apply', style: TextStyle(color: AppColors.accent2, fontWeight: FontWeight.w800)))),
      ]),
    );
  }

  Widget _popcornCard() {
    return _card(child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        for (final p in _popcorn) Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            if (p.image != null) RoundedImage(url: p.image!, width: 42, height: 42, radius: 8),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
              Text(rs(p.price), style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ])),
            _stepBtn(Icons.remove, (_qty[p.id] ?? 0) == 0 ? null : () => _changeQty(p.id, -1)),
            SizedBox(width: 26, child: Text('${_qty[p.id] ?? 0}', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
            _stepBtn(Icons.add, () => _changeQty(p.id, 1)),
          ]),
        ),
      ]),
    ));
  }

  Widget _stepBtn(IconData icon, VoidCallback? onTap) => GestureDetector(
        onTap: onTap,
        child: Container(width: 30, height: 30, alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: onTap == null ? AppColors.line : AppColors.accent, width: 1.4)),
          child: Icon(icon, size: 16, color: onTap == null ? AppColors.line : AppColors.accent2)),
      );

  Widget _paymentSection() {
    final methods = [
      ('card', 'Credit / Debit card', 'Visa, Mastercard, RuPay', Icons.credit_card),
      ('esewa', 'eSewa', 'Wallet (sandbox)', Icons.account_balance_wallet_outlined),
      ('khalti', 'Khalti', 'Wallet (sandbox)', Icons.account_balance_wallet_outlined),
    ];
    return _card(child: Column(children: [
      for (var i = 0; i < methods.length; i++) ...[
        if (i > 0) const Divider(height: 1, indent: 14, endIndent: 14),
        InkWell(
          onTap: () => setState(() => _method = methods[i].$1),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 40, height: 40, alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(methods[i].$4, size: 20, color: AppColors.accent2)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(methods[i].$2, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text)),
                Text(methods[i].$3, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ])),
              Icon(_method == methods[i].$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: _method == methods[i].$1 ? AppColors.accent : AppColors.line),
            ]),
          ),
        ),
      ],
    ]));
  }

  Widget _payBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(color: AppColors.bg, border: Border(top: BorderSide(color: AppColors.line))),
        child: Row(children: [
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('TOTAL', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: .5)),
            Text(rs(_payable), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
          ]),
          const SizedBox(width: 14),
          Expanded(child: AccentButton(label: 'Pay ${rs(_payable)}', loading: _busy, onPressed: () => _pay(_method))),
        ]),
      ),
    );
  }
}
