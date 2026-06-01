import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  Map<String, dynamic> _results = const {};

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() {
        _results = const {};
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _run(q.trim()));
  }

  Future<void> _run(String q) async {
    try {
      final res = await ref.read(apiProvider).search(q);
      if (!mounted) return;
      setState(() {
        _results = res;
        _error = null;
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
    final movies = (_results['movies'] as List? ?? []);
    final events = (_results['events'] as List? ?? []);
    final sports = (_results['sports'] as List? ?? []);
    final empty = movies.isEmpty && events.isEmpty && sports.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search movies, events, sports…',
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: _loading
          ? const Loading()
          : _error != null
              ? ErrorRetry(onRetry: () => _run(_controller.text.trim()), message: _error!)
              : _controller.text.trim().length < 2
                  ? const EmptyView(message: 'Type at least 2 characters', icon: Icons.search)
                  : empty
                      ? const EmptyView(message: 'No results found', icon: Icons.search_off)
                      : ListView(
                          children: [
                            for (final m in movies)
                              _ResultTile(
                                title: m['title'] ?? '',
                                subtitle: (m['genres'] as List?)?.join(', '),
                                icon: Icons.movie_outlined,
                                onTap: () => context.push('/movies/${m['slug']}'),
                              ),
                            for (final e in events)
                              _ResultTile(
                                title: e['title'] ?? '',
                                subtitle: 'Event',
                                icon: Icons.event_outlined,
                                onTap: () => context.push('/events/${e['slug']}'),
                              ),
                            for (final s in sports)
                              _ResultTile(
                                title: s['title'] ?? '',
                                subtitle: 'Sport',
                                icon: Icons.sports_cricket_outlined,
                                onTap: () => context.push('/sports/${s['slug']}'),
                              ),
                          ],
                        ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  const _ResultTile({required this.title, this.subtitle, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.accent),
      title: Text(title),
      subtitle: subtitle != null && subtitle!.isNotEmpty ? Text(subtitle!, style: const TextStyle(color: AppColors.muted)) : null,
      trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
      onTap: onTap,
    );
  }
}
