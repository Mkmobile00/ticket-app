import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/paginated.dart';
import '../../models/sport.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';

final sportsProvider = FutureProvider.autoDispose<Paginated<Sport>>(
  (ref) => ref.read(apiProvider).sports(),
);

class SportsScreen extends ConsumerWidget {
  const SportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sports = ref.watch(sportsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sports')),
      body: sports.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(sportsProvider), message: e.toString()),
        data: (page) {
          if (page.data.isEmpty) return const EmptyView(message: 'No sports events right now', icon: Icons.sports_cricket_outlined);
          return RefreshIndicator(
            color: AppColors.accent,
            onRefresh: () async => ref.invalidate(sportsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: page.data.length,
              itemBuilder: (_, i) {
                final s = page.data[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => context.push('/sports/${s.slug}'),
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          RoundedImage(url: s.bannerImage, width: 110, height: 80),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(s.matchup ?? s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                Text([s.date, s.venue, s.city].where((x) => x != null && x.isNotEmpty).join(' · '),
                                    maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.muted),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
