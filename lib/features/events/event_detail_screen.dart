import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/event.dart';
import '../../providers/providers.dart';
import '../common/web_view_screen.dart';
import '../common/widgets.dart';
import '../seats/seat_map_screen.dart';

final eventProvider = FutureProvider.autoDispose.family<Event, String>(
  (ref, slug) => ref.read(apiProvider).event(slug),
);

class EventDetailScreen extends ConsumerWidget {
  final String slug;
  const EventDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final event = ref.watch(eventProvider(slug));
    return Scaffold(
      body: event.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(eventProvider(slug)), message: e.toString()),
        data: (e) => _content(context, e),
      ),
      bottomNavigationBar: event.maybeWhen(
        data: (e) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AccentButton(
              label: 'Book Tickets',
              onPressed: () => context.push('/seats', extra: SeatArgs(
                type: 'event',
                id: e.id,
                subject: e.title,
                subtitle: [e.date, e.venue].where((x) => x != null && x.isNotEmpty).join(' · '),
              )),
            ),
          ),
        ),
        orElse: () => null,
      ),
    );
  }

  Widget _content(BuildContext context, Event e) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                RoundedImage(url: e.bannerImage, radius: 0),
                if ((e.trailerEmbedUrl ?? '').isNotEmpty)
                  Center(child: TrailerPlayButton(url: e.trailerEmbedUrl!, title: '${e.title} — Trailer')),
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
                Text(e.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (e.date != null) _meta(Icons.calendar_today_outlined, '${e.date}${e.startTime != null ? ' · ${e.startTime}' : ''}'),
                if (e.venue != null) _meta(Icons.location_on_outlined, e.venue!),
                if (e.organizer != null) _meta(Icons.business_outlined, e.organizer!),
                if ((e.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('About', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(e.description!, style: const TextStyle(color: AppColors.muted, height: 1.5)),
                ],
                if (e.tiers.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Ticket tiers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  for (final t in e.tiers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [Text(t.name), Text(rs(t.price), style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700))],
                      ),
                    ),
                ],
                if (e.speakers.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text('Speakers', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  ...e.speakers.map((s) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.surface2,
                          backgroundImage: (s.photo != null && s.photo!.isNotEmpty) ? NetworkImage(s.photo!) : null,
                          child: (s.photo == null || s.photo!.isEmpty) ? const Icon(Icons.person, color: AppColors.muted) : null,
                        ),
                        title: Text(s.name),
                        subtitle: s.designation != null ? Text(s.designation!, style: const TextStyle(color: AppColors.muted)) : null,
                      )),
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
