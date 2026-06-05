import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/sport.dart';
import '../../providers/providers.dart';
import '../common/web_view_screen.dart';
import '../common/widgets.dart';
import '../seats/seat_map_screen.dart';

final sportProvider = FutureProvider.autoDispose.family<Sport, String>(
  (ref, slug) => ref.read(apiProvider).sport(slug),
);

class SportDetailScreen extends ConsumerWidget {
  final String slug;
  const SportDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sport = ref.watch(sportProvider(slug));
    return Scaffold(
      body: sport.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(sportProvider(slug)), message: e.toString()),
        data: (s) => _content(context, s),
      ),
      bottomNavigationBar: sport.maybeWhen(
        data: (s) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AccentButton(
              label: 'Book Tickets',
              onPressed: () => context.push('/seats', extra: SeatArgs(
                type: 'sport',
                id: s.id,
                subject: s.matchup ?? s.title,
                subtitle: [s.date, s.venue].where((x) => x != null && x.isNotEmpty).join(' · '),
              )),
            ),
          ),
        ),
        orElse: () => null,
      ),
    );
  }

  Widget _content(BuildContext context, Sport s) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                RoundedImage(url: s.bannerImage, radius: 0),
                if ((s.trailerEmbedUrl ?? '').isNotEmpty)
                  Center(child: TrailerPlayButton(url: s.trailerEmbedUrl!, title: '${s.title} — Trailer')),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.matchup ?? s.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (s.date != null) _meta(Icons.calendar_today_outlined, '${s.date}${s.startTime != null ? ' · ${s.startTime}' : ''}'),
                if (s.venue != null) _meta(Icons.location_on_outlined, s.venue!),
                if (s.city != null) _meta(Icons.location_city_outlined, s.city!),
                if ((s.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('About', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(s.description!, style: const TextStyle(color: AppColors.muted, height: 1.5)),
                ],
                if (s.tiers.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Ticket tiers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final t in s.tiers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text(t.name), Text(rs(t.price), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700))],
                      ),
                    ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _meta(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.text))),
        ]),
      );
}
