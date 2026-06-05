import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/movie.dart';
import '../../providers/providers.dart';
import '../common/web_view_screen.dart';
import '../common/widgets.dart';

final movieProvider = FutureProvider.autoDispose.family<Movie, String>(
  (ref, slug) => ref.read(apiProvider).movie(slug),
);

class MovieDetailScreen extends ConsumerStatefulWidget {
  final String slug;
  const MovieDetailScreen({super.key, required this.slug});
  @override
  ConsumerState<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends ConsumerState<MovieDetailScreen> {
  bool _expanded = false;

  String _runtime(int? m) {
    if (m == null || m == 0) return '';
    return '${m ~/ 60}h ${m % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final movie = ref.watch(movieProvider(widget.slug));
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: movie.when(
        loading: () => const Loading(),
        error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(movieProvider(widget.slug)), message: e.toString()),
        data: (m) => _content(context, m),
      ),
      bottomNavigationBar: movie.maybeWhen(
        data: (m) => _bookBar(context, m),
        orElse: () => null,
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40, alignment: Alignment.center,
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: .35), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      );

  Widget _content(BuildContext context, Movie m) {
    final chips = <String>[
      'UA',
      if (_runtime(m.durationMinutes).isNotEmpty) _runtime(m.durationMinutes),
      if (m.genres.isNotEmpty) m.genres.join(' · '),
      if (m.languages.isNotEmpty) m.languages.join(' · '),
      if (m.formats.isNotEmpty) m.formats.join(' · '),
    ];
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 300,
          pinned: false,
          backgroundColor: AppColors.bg,
          automaticallyImplyLeading: false,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              RoundedImage(url: m.bannerImage ?? m.posterImage, radius: 0),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.center,
                colors: [AppColors.bg, Colors.transparent]))),
              SafeArea(child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Row(children: [
                  _circleBtn(Icons.arrow_back, () => context.pop()),
                  const Spacer(),
                  _circleBtn(Icons.favorite_border, () {}),
                  const SizedBox(width: 10),
                  _circleBtn(Icons.share_outlined, () {}),
                ]),
              )),
              if ((m.trailerEmbedUrl ?? '').isNotEmpty)
                Center(child: TrailerPlayButton(url: m.trailerEmbedUrl!, title: '${m.title} — Trailer')),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.5, color: AppColors.text)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [for (final c in chips) _chip(c)]),

              if (m.userRating != null && m.userRating! > 0) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
                  child: Row(children: [
                    const Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 22),
                    const SizedBox(width: 8),
                    Text(m.userRating!.toStringAsFixed(1), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                    const Text(' /5', style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    const Text('Rate now', style: TextStyle(color: AppColors.accent2, fontWeight: FontWeight.w800)),
                  ]),
                ),
              ],

              if ((m.synopsis ?? '').isNotEmpty) ...[
                const SizedBox(height: 18),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  alignment: Alignment.topCenter,
                  child: Text(m.synopsis!,
                      maxLines: _expanded ? null : 3, overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, height: 1.55, fontSize: 14.5)),
                ),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(_expanded ? 'Read less' : 'Read more', style: const TextStyle(color: AppColors.accent2, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],

              if (m.cast.isNotEmpty) ...[
                const SizedBox(height: 22),
                Row(children: [
                  const Text('Cast & Crew', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.text)),
                  const Spacer(),
                  const Text('See all', style: TextStyle(color: AppColors.accent2, fontWeight: FontWeight.w800, fontSize: 13.5)),
                ]),
                const SizedBox(height: 14),
                SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: m.cast.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, i) {
                      final c = m.cast[i];
                      final role = (c.role ?? '').toLowerCase();
                      final sub = role == 'actor' || role == '' ? (c.character ?? 'Cast') : '${role[0].toUpperCase()}${role.substring(1)}';
                      return SizedBox(
                        width: 76,
                        child: Column(children: [
                          Container(
                            width: 66, height: 66, alignment: Alignment.center,
                            decoration: BoxDecoration(gradient: _avatarGradient(i), shape: BoxShape.circle),
                            child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
                          ),
                          const SizedBox(height: 8),
                          Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.text)),
                          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                        ]),
                      );
                    },
                  ),
                ),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.line)),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _ink2)),
      );

  LinearGradient _avatarGradient(int i) {
    const pairs = [
      [Color(0xFF8d5a52), Color(0xFF5a3530)], [Color(0xFF7a4f86), Color(0xFF4f2f5a)],
      [Color(0xFF4a5a8d), Color(0xFF2f3a66)], [Color(0xFF3f6f5e), Color(0xFF274b3f)],
      [Color(0xFF8a7d1f), Color(0xFF5a5210)],
    ];
    final p = pairs[i % pairs.length];
    return LinearGradient(colors: p, begin: Alignment.topLeft, end: Alignment.bottomRight);
  }

  Widget _bookBar(BuildContext context, Movie m) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: const BoxDecoration(
          color: AppColors.bg,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: GestureDetector(
          onTap: () => context.push('/movies/${widget.slug}/showtimes', extra: m.title),
          child: Container(
            height: 54, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.line),
              boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .18), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Book tickets', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward, size: 18, color: AppColors.text),
            ]),
          ),
        ),
      ),
    );
  }
}

const _ink2 = Color(0xFF46535F);
