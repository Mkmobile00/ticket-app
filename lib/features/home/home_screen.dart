import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/city.dart';
import '../../providers/providers.dart';
import '../common/web_view_screen.dart';
import '../common/widgets.dart';

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
    // Restore a previously chosen city.
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

  /// Auto-open the city popup on first visit when nothing is chosen yet.
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
    final city = ref.watch(selectedCityProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: ShaderMask(
          shaderCallback: (b) => AppColors.accentGradient.createShader(b),
          child: const Text('BULETO', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _pickCity(context, ref, home.valueOrNull),
            icon: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.accent),
            label: Text(city?.name ?? 'All cities', style: const TextStyle(color: AppColors.text)),
          ),
          if (ref.watch(authProvider).status != AuthStatus.authenticated)
            TextButton(
              onPressed: () => context.push('/login'),
              child: const Text('Login', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: home.when(
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
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text('Hi ${user?.name.split(' ').first ?? 'there'} 👋',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                ),
                _SearchBar(onTap: () => context.push('/search')),
                if (banners.isNotEmpty) _BannerCarousel(banners: banners),
                _Rail(
                  title: 'Now Showing',
                  onSeeAll: () => context.go('/movies'),
                  items: nowShowing,
                  isPoster: true,
                  onTap: (m) => context.push('/movies/${m['slug']}'),
                ),
                _Rail(
                  title: 'Events',
                  onSeeAll: () => context.push('/events'),
                  items: events,
                  isPoster: false,
                  onTap: (m) => context.push('/events/${m['slug']}'),
                ),
                _Rail(
                  title: 'Sports',
                  onSeeAll: () => context.push('/sports'),
                  items: sports,
                  isPoster: false,
                  onTap: (m) => context.push('/sports/${m['slug']}'),
                ),
              ],
            ),
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
          Navigator.of(dialogCtx).pop(); // pop the dialog (root navigator), not the home route
        },
      ),
    );
  }
}

/// BookMyShow-style "select your city" popup with a search + grid of cities.
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
            Row(
              children: [
                const Expanded(child: Text('Select your city', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
                IconButton(icon: const Icon(Icons.close, color: AppColors.muted), onPressed: () => Navigator.pop(context)),
              ],
            ),
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

class _SearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchBar({required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(12)),
          child: const Row(
            children: [
              Icon(Icons.search, color: AppColors.muted),
              SizedBox(width: 10),
              Text('Search movies, events, sports…', style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  final List banners;
  const _BannerCarousel({required this.banners});
  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController(viewportFraction: .9);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: SizedBox(
        height: 160,
        child: PageView.builder(
          controller: _controller,
          itemCount: widget.banners.length,
          itemBuilder: (_, i) {
            final b = Map<String, dynamic>.from(widget.banners[i]);
            final link = b['link'] as String?;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () => handleBannerLink(context, link, b['title'] as String?),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RoundedImage(url: b['image'] ?? '', radius: 14),
                    if ((b['title'] ?? '').toString().isNotEmpty)
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black.withValues(alpha: .7), Colors.transparent],
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(b['title'], style: const TextStyle(fontWeight: FontWeight.w700))),
                              if (link != null && link.trim().isNotEmpty)
                                const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final String title;
  final List items;
  final bool isPoster;
  final VoidCallback onSeeAll;
  final void Function(Map<String, dynamic>) onTap;
  const _Rail({
    required this.title,
    required this.items,
    required this.isPoster,
    required this.onSeeAll,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              TextButton(onPressed: onSeeAll, child: const Text('See all', style: TextStyle(color: AppColors.accent))),
            ],
          ),
        ),
        SizedBox(
          height: isPoster ? 240 : 170,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final m = Map<String, dynamic>.from(items[i]);
              final img = (m['poster_image'] ?? m['banner_image'] ?? '') as String;
              return SizedBox(
                width: isPoster ? 130 : 240,
                child: isPoster
                    ? PosterTile(
                        image: img,
                        title: m['title'] ?? '',
                        rating: (m['user_rating'] as num?)?.toDouble(),
                        onTap: () => onTap(m),
                      )
                    : GestureDetector(
                        onTap: () => onTap(m),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RoundedImage(url: img, width: double.infinity, height: 120),
                            const SizedBox(height: 6),
                            Text(m['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (m['date'] != null)
                              Text(m['date'], style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}
