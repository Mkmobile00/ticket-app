import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../models/city.dart';
import '../../providers/providers.dart';
import '../common/web_view_screen.dart';
import '../common/widgets.dart';

const _gold = Color(0xFFF5A623);
const _ink2 = Color(0xFF46535F);

/// Acts on a banner's optional deep-link: in-app route ("/movies/x") or http URL.
void handleBannerLink(BuildContext context, String? link, [String? title]) {
  if (link == null || link.trim().isEmpty) return;
  final l = link.trim();
  if (l.startsWith('http://') || l.startsWith('https://')) {
    context.push('/web', extra: WebArgs(url: l, title: title));
  } else if (l.startsWith('/')) {
    context.push(l);
  }
}

String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '';
  try {
    return DateFormat('EEE, d MMM').format(DateTime.parse(raw));
  } catch (_) {
    return raw;
  }
}

/// One call powers the whole home screen.
final homeProvider = FutureProvider.autoDispose<Map<String, dynamic>>(
  (ref) => ref.read(apiProvider).home(),
);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _cityPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (ref.read(selectedCityProvider) != null) return;
      final saved = await ref.read(cityStoreProvider).read();
      if (saved != null && mounted) {
        ref.read(selectedCityProvider.notifier).state = saved;
      }
    });
  }

  void _selectCity(City? c) {
    ref.read(selectedCityProvider.notifier).state = c;
    ref.read(cityStoreProvider).write(c);
  }

  void _maybeAutoPrompt(Map<String, dynamic> data) {
    if (_cityPrompted || ref.read(selectedCityProvider) != null) return;
    _cityPrompted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ref.read(selectedCityProvider) == null) {
        _pickCity(context, ref, data);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = ref.watch(homeProvider);
    final user = ref.watch(authProvider).user;
    final authed = ref.watch(authProvider).status == AuthStatus.authenticated;
    final city = ref.watch(selectedCityProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [AppColors.accentSoft, AppColors.bg],
            stops: [0, .35],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _header(context, city, authed, user?.name),
              Expanded(
                child: home.when(
                  loading: () => const Loading(),
                  error: (e, _) => ErrorRetry(onRetry: () => ref.invalidate(homeProvider)),
                  data: (data) {
                    _maybeAutoPrompt(data);
                    final banners = (data['banners'] as List? ?? []);
                    final nowShowing = (data['now_showing'] as List? ?? []);
                    final events = (data['events'] as List? ?? []);
                    final sports = (data['sports'] as List? ?? []);
                    return RefreshIndicator(
                      color: AppColors.accent,
                      onRefresh: () async => ref.invalidate(homeProvider),
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 20),
                        children: [
                          _greeting(user?.name),
                          _searchBar(context),
                          if (banners.isNotEmpty) _HeroCarousel(banners: banners),
                          _SecHead(title: 'Now Showing', onSeeAll: () => context.go('/movies')),
                          _posterRail(context, nowShowing),
                          _SecHead(title: 'Events', onSeeAll: () => context.push('/events')),
                          _wideRail(context, events, '/events'),
                          _SecHead(title: 'Sports', onSeeAll: () => context.push('/sports')),
                          _wideRail(context, sports, '/sports'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- header ----------------
  Widget _header(BuildContext context, City? city, bool authed, String? name) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 16, 12),
      child: Row(
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: .5),
              children: [
                TextSpan(text: 'BU', style: TextStyle(color: AppColors.accent)),
                TextSpan(text: 'LETO', style: TextStyle(color: AppColors.text)),
              ],
            ),
          ),
          const Spacer(),
          // location pill
          GestureDetector(
            onTap: () => _pickCity(context, ref, ref.read(homeProvider).valueOrNull),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.location_on, size: 14, color: AppColors.accent),
                const SizedBox(width: 4),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 78),
                  child: Text(city?.name ?? 'All cities',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ink2)),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          // bell
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.line),
              ),
              child: Stack(alignment: Alignment.center, children: [
                const Icon(Icons.notifications_none_rounded, size: 21, color: AppColors.text),
                Positioned(
                  top: 9, right: 10,
                  child: Container(width: 7, height: 7,
                    decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2))),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          if (!authed)
            GestureDetector(
              onTap: () => context.push('/login'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(999)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.person_outline, size: 15, color: Colors.white),
                  SizedBox(width: 6),
                  Text('Login', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5)),
                ]),
              ),
            )
          else
            GestureDetector(
              onTap: () => context.go('/account'),
              child: Container(
                width: 40, height: 40, alignment: Alignment.center,
                decoration: const BoxDecoration(gradient: AppColors.accentGradient, shape: BoxShape.circle),
                child: Text((name?.isNotEmpty == true ? name![0] : '?').toUpperCase(),
                    style: const TextStyle(color: AppColors.onAccent, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _greeting(String? name) {
    final first = (name == null || name.isEmpty) ? 'there' : name.split(' ').first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Hi $first', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.4, color: AppColors.text)),
        const SizedBox(height: 3),
        const Text('Find movies, events & sports near you',
            style: TextStyle(fontSize: 14, color: AppColors.muted, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _searchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: GestureDetector(
        onTap: () => context.push('/search'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 13, 8, 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(children: [
            const Icon(Icons.search, color: AppColors.muted, size: 21),
            const SizedBox(width: 10),
            const Expanded(child: Text('Search movies, events, sports…',
                style: TextStyle(color: AppColors.muted, fontSize: 15, fontWeight: FontWeight.w500))),
            Container(width: 34, height: 34,
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.tune, color: Colors.white, size: 18)),
          ]),
        ),
      ),
    );
  }

  Widget _posterRail(BuildContext context, List items) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 262,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final m = Map<String, dynamic>.from(items[i]);
          final genres = (m['genres'] as List?)?.cast<String>().join(' · ') ?? '';
          return _PosterCard(
            image: (m['poster_image'] ?? '') as String,
            title: (m['title'] ?? '') as String,
            genre: genres,
            rating: (m['user_rating'] as num?)?.toDouble(),
            onTap: () => context.push('/movies/${m['slug']}'),
          );
        },
      ),
    );
  }

  Widget _wideRail(BuildContext context, List items, String base) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 236,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (_, i) {
          final m = Map<String, dynamic>.from(items[i]);
          return _WideCard(
            image: (m['banner_image'] ?? '') as String,
            title: (m['title'] ?? '') as String,
            date: _fmtDate(m['date'] as String?),
            venue: (m['venue'] ?? m['city'] ?? '') as String,
            onTap: () => context.push('$base/${m['slug']}'),
          );
        },
      ),
    );
  }

  void _pickCity(BuildContext context, WidgetRef ref, Map<String, dynamic>? home) {
    final cities = ((home?['cities'] as List?) ?? [])
        .map((e) => City.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: .7),
      builder: (dialogCtx) => _CityDialog(
        cities: cities,
        selectedId: ref.read(selectedCityProvider)?.id,
        onSelect: (c) {
          _selectCity(c);
          Navigator.of(dialogCtx).pop();
        },
      ),
    );
  }
}

// ---------------- section header ----------------
class _SecHead extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  const _SecHead({required this.title, required this.onSeeAll});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -.3, color: AppColors.text)),
          const Spacer(),
          GestureDetector(onTap: onSeeAll,
            child: const Text('See all', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.accent2))),
        ],
      ),
    );
  }
}

// ---------------- hero carousel ----------------
class _HeroCarousel extends StatefulWidget {
  final List banners;
  const _HeroCarousel({required this.banners});
  @override
  State<_HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<_HeroCarousel> {
  final _pc = PageController();
  int _i = 0;
  @override
  void dispose() { _pc.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: SizedBox(
          height: 184,
          child: PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _i = i),
            itemCount: widget.banners.length,
            itemBuilder: (_, i) {
              final b = Map<String, dynamic>.from(widget.banners[i]);
              return GestureDetector(
                onTap: () => handleBannerLink(context, b['link'] as String?, b['title'] as String?),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(fit: StackFit.expand, children: [
                    RoundedImage(url: (b['image'] ?? '') as String, radius: 0),
                    DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft, end: Alignment.centerRight,
                          colors: [Color(0xCC0A1F1B), Color(0x33000000)],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Text('FEATURED',
                              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.6)),
                          const SizedBox(height: 6),
                          Text((b['title'] ?? 'Now showing') as String,
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, height: 1.15)),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('Explore now', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700, fontSize: 13)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward, size: 15, color: AppColors.text),
                            ]),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (int j = 0; j < widget.banners.length; j++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: j == _i ? 18 : 6, height: 6,
            decoration: BoxDecoration(
              color: j == _i ? AppColors.accent : AppColors.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
      ]),
    ]);
  }
}

// ---------------- poster card ----------------
class _PosterCard extends StatelessWidget {
  final String image, title, genre;
  final double? rating;
  final VoidCallback onTap;
  const _PosterCard({required this.image, required this.title, required this.genre, this.rating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 148,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(children: [
              RoundedImage(url: image, width: 148, height: 212, radius: 0),
              if (rating != null)
                Positioned(top: 9, right: 9, child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xB00B0D0E), borderRadius: BorderRadius.circular(999)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.star_rounded, size: 13, color: _gold),
                    const SizedBox(width: 3),
                    Text(rating!.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ]),
                )),
              Positioned(left: 0, right: 0, bottom: 0, child: Container(
                padding: const EdgeInsets.fromLTRB(12, 30, 12, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                    colors: [Color(0xC8081012), Colors.transparent]),
                ),
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              )),
            ]),
          ),
          if (genre.isNotEmpty)
            Padding(padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
              child: Text(genre, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

// ---------------- wide card ----------------
class _WideCard extends StatelessWidget {
  final String image, title, date, venue;
  final VoidCallback onTap;
  const _WideCard({required this.image, required this.title, required this.date, required this.venue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 264,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: RoundedImage(url: image, width: double.infinity, height: 138, radius: 0),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 14, 15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -.2, color: AppColors.text)),
              if (date.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.accent),
                  const SizedBox(width: 7),
                  Text(date, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _ink2)),
                ]),
              ],
              if (venue.isNotEmpty) ...[
                const SizedBox(height: 5),
                Row(children: [
                  const Icon(Icons.location_on_outlined, size: 13, color: AppColors.muted),
                  const SizedBox(width: 7),
                  Expanded(child: Text(venue, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.muted))),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

// ---------------- city dialog ----------------
class _CityDialog extends StatefulWidget {
  final List<City> cities;
  final int? selectedId;
  final void Function(City?) onSelect;
  const _CityDialog({required this.cities, required this.selectedId, required this.onSelect});

  @override
  State<_CityDialog> createState() => _CityDialogState();
}

class _CityDialogState extends State<_CityDialog> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.cities
        .where((c) => c.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Expanded(child: Text('Select your city', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
              IconButton(icon: const Icon(Icons.close, color: AppColors.muted), onPressed: () => Navigator.pop(context)),
            ]),
            const SizedBox(height: 8),
            TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, color: AppColors.muted),
                hintText: 'Search for your city',
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: () => widget.onSelect(null),
              icon: const Icon(Icons.public, size: 18, color: AppColors.accent),
              label: const Text('All cities', style: TextStyle(color: AppColors.text)),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20), child: Text('No city found.', style: TextStyle(color: AppColors.muted)))
                  : GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      childAspectRatio: .95,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        for (final c in filtered)
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => widget.onSelect(c),
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(12),
                                border: widget.selectedId == c.id ? Border.all(color: AppColors.accent) : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  (c.icon != null && c.icon!.isNotEmpty)
                                      ? Image.network(c.icon!, width: 34, height: 34, fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.location_city, color: AppColors.accent2, size: 30))
                                      : const Icon(Icons.location_city, color: AppColors.accent2, size: 30),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: Text(c.name,
                                        maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
