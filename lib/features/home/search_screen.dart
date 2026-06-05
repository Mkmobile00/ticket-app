import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';

const _ink2 = Color(0xFF46535F);
const _recent = ['Jawan', 'Pathaan', 'IMAX', 'Comedy', 'Weekend'];

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
  String _cat = 'All';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 2) {
      setState(() { _results = const {}; _error = null; _loading = false; });
      return;
    }
    setState(() => _loading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () => _run(q.trim()));
  }

  void _setQuery(String q) {
    _controller.text = q;
    _controller.selection = TextSelection.collapsed(offset: q.length);
    _onChanged(q);
  }

  Future<void> _run(String q) async {
    try {
      final res = await ref.read(apiProvider).search(q);
      if (!mounted) return;
      setState(() { _results = res; _error = null; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // search bar + cancel
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
            child: Row(children: [
              Expanded(child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.line)),
                child: Row(children: [
                  const Icon(Icons.search, size: 20, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(
                    controller: _controller, autofocus: true, onChanged: _onChanged, textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      hintText: 'Search movies, events, sports…', isDense: true, filled: false,
                      border: InputBorder.none, enabledBorder: InputBorder.none, focusedBorder: InputBorder.none,
                    ),
                  )),
                  if (_controller.text.isNotEmpty)
                    GestureDetector(onTap: () { _controller.clear(); _onChanged(''); setState(() {}); },
                        child: const Icon(Icons.close, size: 18, color: AppColors.muted)),
                ]),
              )),
              TextButton(onPressed: () => context.pop(), child: const Text('Cancel', style: TextStyle(color: AppColors.accent2, fontWeight: FontWeight.w700))),
            ]),
          ),
          // category chips
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 4,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                const cats = ['All', 'Movies', 'Events', 'Sports'];
                final on = _cat == cats[i];
                return GestureDetector(
                  onTap: () => setState(() => _cat = cats[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18), alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: on ? AppColors.text : AppColors.surface, borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: on ? AppColors.text : AppColors.line)),
                    child: Text(cats[i], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: on ? Colors.white : _ink2)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _body()),
        ]),
      ),
    );
  }

  Widget _body() {
    if (_controller.text.trim().length < 2) {
      return ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 20), children: [
        const Text('RECENT SEARCHES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6, color: AppColors.muted)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final r in _recent) GestureDetector(
            onTap: () => _setQuery(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.line)),
              child: Text(r, style: const TextStyle(fontWeight: FontWeight.w600, color: _ink2, fontSize: 13)),
            ),
          ),
        ]),
      ]);
    }
    if (_loading) return const Loading();
    if (_error != null) return ErrorRetry(onRetry: () => _run(_controller.text.trim()), message: _error!);

    final movies = (_results['movies'] as List? ?? []);
    final events = (_results['events'] as List? ?? []);
    final sports = (_results['sports'] as List? ?? []);
    final rows = <Widget>[];
    if (_cat == 'All' || _cat == 'Movies') {
      for (final m in movies) {
        rows.add(_tile(
          title: m['title'] ?? '',
          meta: ['Movie', ...((m['genres'] as List?)?.cast<String>() ?? const [])].join(' · '),
          image: m['poster_image'] as String?,
          rating: (m['user_rating'] as num?)?.toDouble(),
          onTap: () => context.push('/movies/${m['slug']}'),
        ));
      }
    }
    if (_cat == 'All' || _cat == 'Events') {
      for (final e in events) {
        rows.add(_tile(title: e['title'] ?? '', meta: 'Event', image: e['banner_image'] as String?, onTap: () => context.push('/events/${e['slug']}')));
      }
    }
    if (_cat == 'All' || _cat == 'Sports') {
      for (final s in sports) {
        rows.add(_tile(title: s['title'] ?? '', meta: 'Sport', image: s['banner_image'] as String?, onTap: () => context.push('/sports/${s['slug']}')));
      }
    }
    if (rows.isEmpty) return const EmptyView(message: 'No results found', icon: Icons.search_off);

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 20), children: [
      const Padding(padding: EdgeInsets.fromLTRB(4, 6, 0, 12),
          child: Text('RESULTS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .6, color: AppColors.muted))),
      ...rows,
    ]);
  }

  Widget _tile({required String title, required String meta, String? image, double? rating, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: (image != null && image.isNotEmpty)
                ? RoundedImage(url: image, width: 50, height: 50, radius: 0)
                : Container(width: 50, height: 50, decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF8d5a52), Color(0xFF5a3530)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.text)),
            const SizedBox(height: 3),
            Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12.5)),
          ])),
          if (rating != null && rating > 0) ...[
            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
            const SizedBox(width: 3),
            Text(rating.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800, color: _ink2, fontSize: 13.5)),
          ],
        ]),
      ),
    );
  }
}
