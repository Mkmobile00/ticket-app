import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/movie.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';

final movieProvider = FutureProvider.autoDispose.family<Movie, String>(
  (ref, slug) => ref.read(apiProvider).movie(slug),
);

class MovieDetailScreen extends ConsumerWidget {
  final String slug;
  const MovieDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movie = ref.watch(movieProvider(slug));
    return Scaffold(
      body: movie.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(movieProvider(slug)), message: e.toString()),
        data: (m) => _content(context, m),
      ),
      bottomNavigationBar: movie.maybeWhen(
        data: (m) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: AccentButton(
              label: 'Book Tickets',
              onPressed: () => context.push('/movies/$slug/showtimes', extra: m.title),
            ),
          ),
        ),
        orElse: () => null,
      ),
    );
  }

  Widget _content(BuildContext context, Movie m) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 280,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                RoundedImage(url: m.bannerImage ?? m.posterImage, radius: 0),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.center,
                      colors: [AppColors.bg, Colors.transparent],
                    ),
                  ),
                ),
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
                Text(m.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (m.userRating != null && m.userRating! > 0) ...[
                      const Icon(Icons.star, color: AppColors.accent, size: 18),
                      const SizedBox(width: 4),
                      Text('${m.userRating!.toStringAsFixed(1)}/5', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 14),
                    ],
                    if (m.durationMinutes != null) ...[
                      const Icon(Icons.schedule, color: AppColors.muted, size: 16),
                      const SizedBox(width: 4),
                      Text('${m.durationMinutes} min', style: const TextStyle(color: AppColors.muted)),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ...m.genres.map((g) => TagChip(g)),
                    ...m.languages.map((l) => TagChip(l)),
                    ...m.formats.map((f) => TagChip(f)),
                  ],
                ),
                if ((m.synopsis ?? '').isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Synopsis', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(m.synopsis!, style: const TextStyle(color: AppColors.muted, height: 1.5)),
                ],
                if (m.cast.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Cast', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: m.cast.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final c = m.cast[i];
                        return Chip(
                          backgroundColor: AppColors.surface2,
                          label: Text(c.character != null ? '${c.name} · ${c.character}' : c.name),
                          side: BorderSide.none,
                        );
                      },
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
}
