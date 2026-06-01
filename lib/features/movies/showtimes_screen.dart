import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/showtime.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';
import '../seats/seat_map_screen.dart';

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
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final city = ref.read(selectedCityProvider)?.id;
      final res = await ref.read(apiProvider).showtimes(widget.slug, city: city, date: _ymd(_selected));
      if (!mounted) return;
      setState(() {
        _groups = res;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.movieTitle ?? 'Showtimes')),
      body: Column(
        children: [
          _dateStrip(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _dateStrip() {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        itemCount: _dates.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final d = _dates[i];
          final selected = _ymd(d) == _ymd(_selected);
          return GestureDetector(
            onTap: () {
              setState(() => _selected = d);
              _load();
            },
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                gradient: selected ? AppColors.accentGradient : null,
                color: selected ? null : AppColors.surface2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(weekdays[d.weekday - 1], style: TextStyle(fontSize: 11, color: selected ? Colors.white : AppColors.muted)),
                  const SizedBox(height: 2),
                  Text('${d.day}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: selected ? Colors.white : AppColors.text)),
                  Text(months[d.month - 1], style: TextStyle(fontSize: 10, color: selected ? Colors.white : AppColors.muted)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Loading();
    if (_error != null) return ErrorRetry(onRetry: _load, message: _error!);
    if (_groups.isEmpty) return const EmptyView(message: 'No showtimes for this day', icon: Icons.event_busy);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _groups.length,
      itemBuilder: (_, i) {
        final g = _groups[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g.cinemaName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                if (g.city != null) Text(g.city!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: g.showtimes.map((s) => _showtimeChip(g, s)).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _showtimeChip(CinemaShowtimes g, Showtime s) {
    return GestureDetector(
      onTap: () => context.push('/seats', extra: SeatArgs(
        type: 'showtime',
        id: s.id,
        subject: widget.movieTitle ?? 'Movie',
        subtitle: '${g.cinemaName} · ${s.time ?? ''} · ${s.format ?? ''}',
      )),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent.withValues(alpha: .6)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.time ?? '--', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent)),
            Text([s.format, s.language].where((e) => e != null).join(' · '),
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
