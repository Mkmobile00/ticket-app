import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/showtime.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';
import '../seats/seat_map_screen.dart';

const _ink2 = Color(0xFF46535F);

class ShowtimesScreen extends ConsumerStatefulWidget {
  final String slug;
  final String? movieTitle;
  const ShowtimesScreen({super.key, required this.slug, this.movieTitle});

  @override
  ConsumerState<ShowtimesScreen> createState() => _ShowtimesScreenState();
}

class _ShowtimesScreenState extends ConsumerState<ShowtimesScreen> {
  late List<DateTime> _dates;
  DateTime _selected = DateTime.now();
  bool _loading = true;
  String? _error;
  List<CinemaShowtimes> _groups = [];
  String _format = 'All formats';

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _dates = List.generate(7, (i) => DateTime(today.year, today.month, today.day).add(Duration(days: i)));
    _selected = _dates.first;
    _load();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final city = ref.read(selectedCityProvider)?.id;
      var res = await ref.read(apiProvider).showtimes(widget.slug, city: city, date: _ymd(_selected));
      // The selected city may have no cinemas (e.g. Ahmedabad) — fall back to all cities.
      if (res.isEmpty && city != null) {
        res = await ref.read(apiProvider).showtimes(widget.slug, city: null, date: _ymd(_selected));
      }
      if (!mounted) return;
      setState(() { _groups = res; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<String> get _formats {
    final set = <String>{};
    for (final g in _groups) {
      for (final s in g.showtimes) {
        if ((s.format ?? '').isNotEmpty) set.add(s.format!);
      }
    }
    return ['All formats', ...set];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 16, 6),
            child: Row(children: [
              _circleBack(),
              const SizedBox(width: 8),
              Expanded(child: Text(widget.movieTitle ?? 'Showtimes',
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text))),
            ]),
          ),
          _dateStrip(),
          const SizedBox(height: 6),
          _formatStrip(),
          const SizedBox(height: 4),
          Expanded(child: _bodyView()),
        ]),
      ),
    );
  }

  Widget _circleBack() => GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: AppColors.surface, shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
          child: const Icon(Icons.arrow_back, size: 20, color: AppColors.text),
        ),
      );

  Widget _dateStrip() {
    const weekdays = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return SizedBox(
      height: 78,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final d = _dates[i];
          final sel = _ymd(d) == _ymd(_selected);
          return GestureDetector(
            onTap: () { setState(() => _selected = d); _load(); },
            child: Container(
              width: 58,
              decoration: BoxDecoration(
                color: sel ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: sel ? AppColors.accent : AppColors.line),
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(weekdays[d.weekday - 1], style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: sel ? Colors.white70 : AppColors.muted)),
                const SizedBox(height: 3),
                Text('${d.day}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: sel ? Colors.white : AppColors.text)),
                Text(months[d.month - 1], style: TextStyle(fontSize: 10.5, color: sel ? Colors.white70 : AppColors.muted)),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _formatStrip() {
    final fmts = _formats;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: fmts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final f = fmts[i];
          final on = f == _format;
          return GestureDetector(
            onTap: () => setState(() => _format = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? AppColors.text : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: on ? AppColors.text : AppColors.line),
              ),
              child: Text(f, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? Colors.white : _ink2)),
            ),
          );
        },
      ),
    );
  }

  Widget _bodyView() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorRetry(onRetry: _load, message: _error!);
    if (_groups.isEmpty) return const EmptyView(message: 'No showtimes for this day', icon: Icons.event_busy);

    final groups = _groups.map((g) {
      final shows = _format == 'All formats' ? g.showtimes : g.showtimes.where((s) => s.format == _format).toList();
      return (g, shows);
    }).where((e) => e.$2.isNotEmpty).toList();

    if (groups.isEmpty) return const EmptyView(message: 'No shows in this format', icon: Icons.event_busy);

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: groups.length,
      itemBuilder: (_, i) {
        final (g, shows) = groups[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.cinemaName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppColors.text)),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Text(g.city ?? 'Cinema', style: const TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 12, runSpacing: 12, children: shows.map((s) => _showtimeChip(g, s)).toList()),
          ]),
        );
      },
    );
  }

  Widget _showtimeChip(CinemaShowtimes g, Showtime s) {
    final filling = (s.availableSeats ?? 999) <= 40;
    final accent = filling ? const Color(0xFFCF8A1E) : AppColors.accent2;
    return GestureDetector(
      onTap: () => context.push('/seats', extra: SeatArgs(
        type: 'showtime',
        id: s.id,
        subject: widget.movieTitle ?? 'Movie',
        subtitle: '${g.cinemaName} · ${s.time ?? ''} · ${s.format ?? ''}',
      )),
      child: Container(
        width: 78,
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: accent.withValues(alpha: .6), width: 1.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Text(s.time ?? '--', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: accent)),
          const SizedBox(height: 2),
          Text(filling ? 'FILLING FAST' : (s.format ?? ''),
              maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: filling ? const Color(0xFFCF8A1E) : AppColors.muted)),
        ]),
      ),
    );
  }
}
