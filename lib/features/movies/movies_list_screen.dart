import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/movie.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';

class MoviesListScreen extends ConsumerStatefulWidget {
  const MoviesListScreen({super.key});
  @override
  ConsumerState<MoviesListScreen> createState() => _MoviesListScreenState();
}

class _MoviesListScreenState extends ConsumerState<MoviesListScreen> {
  final _scroll = ScrollController();
  final List<Movie> _movies = [];
  List<Map<String, dynamic>> _genres = [];
  String? _genre;
  int _page = 1;
  int _lastPage = 1;
  bool _loading = false;
  bool _initial = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadGenres();
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    try {
      final g = await ref.read(apiProvider).options('genres');
      if (mounted) setState(() => _genres = g);
    } catch (_) {}
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400 &&
        !_loading &&
        _page < _lastPage) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _initial = true;
      _error = null;
      _page = 1;
      _movies.clear();
    });
    await _fetch(1);
  }

  Future<void> _loadMore() async => _fetch(_page + 1);

  Future<void> _fetch(int page) async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final city = ref.read(selectedCityProvider)?.id;
      final res = await ref.read(apiProvider).movies(genre: _genre, city: city, page: page);
      if (!mounted) return;
      setState(() {
        _movies.addAll(res.data);
        _page = res.currentPage;
        _lastPage = res.lastPage;
        _loading = false;
        _initial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _initial = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reload when city changes.
    ref.listen(selectedCityProvider, (_, __) => _reload());

    return Scaffold(
      appBar: AppBar(title: const Text('Movies')),
      body: Column(
        children: [
          _genreFilter(),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _genreFilter() {
    if (_genres.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _chip('All', _genre == null, () {
            setState(() => _genre = null);
            _reload();
          }),
          for (final g in _genres)
            _chip(g['name'], _genre == g['slug'], () {
              setState(() => _genre = g['slug'] as String?);
              _reload();
            }),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.accent,
        backgroundColor: AppColors.surface2,
        labelStyle: TextStyle(color: selected ? Colors.white : AppColors.text),
        side: BorderSide.none,
      ),
    );
  }

  Widget _body() {
    if (_initial && _loading) return const Loading();
    if (_error != null && _movies.isEmpty) return ErrorRetry(onRetry: _reload, message: _error!);
    if (_movies.isEmpty) return const EmptyView(message: 'No movies found', icon: Icons.movie_outlined);

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _reload,
      child: GridView.builder(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: .52,
          crossAxisSpacing: 14,
          mainAxisSpacing: 16,
        ),
        itemCount: _movies.length + (_page < _lastPage ? 2 : 0),
        itemBuilder: (_, i) {
          if (i >= _movies.length) return const Loading();
          final m = _movies[i];
          return PosterTile(
            image: m.posterImage,
            title: m.title,
            rating: m.userRating,
            subtitle: m.genres.take(2).join(', '),
            onTap: () => context.push('/movies/${m.slug}'),
          );
        },
      ),
    );
  }
}
