import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/event.dart';
import '../../models/paginated.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';

final eventsProvider = FutureProvider.autoDispose<Paginated<Event>>(
  (ref) => ref.read(apiProvider).events(),
);

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Events')),
      body: events.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(eventsProvider), message: e.toString()),
        data: (page) {
          if (page.data.isEmpty) return const EmptyView(message: 'No events right now', icon: Icons.event_outlined);
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async => ref.invalidate(eventsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: page.data.length,
              itemBuilder: (_, i) {
                final e = page.data[i];
                return _ListCard(
                  image: e.bannerImage,
                  title: e.title,
                  subtitle: [e.date, e.venue].where((x) => x != null && x.isNotEmpty).join(' · '),
                  onTap: () => context.push('/events/${e.slug}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

/// Shared landscape list card for events & sports.
class _ListCard extends StatelessWidget {
  final String image;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ListCard({required this.image, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              RoundedImage(url: image, width: 110, height: 80),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
