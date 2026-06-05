import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../models/app_notification.dart';
import '../../providers/providers.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening the inbox clears the unread badge.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(notificationsProvider.notifier).markAllRead());
  }

  String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  IconData _icon(String type) => switch (type) {
        'booking' => Icons.confirmation_number_outlined,
        'reminder' => Icons.alarm,
        'movie' => Icons.local_movies_outlined,
        _ => Icons.notifications_none,
      };

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => ref.read(notificationsProvider.notifier).clear(),
            ),
        ],
      ),
      body: items.isEmpty
          ? const _Empty()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) => _Tile(n: items[i], ago: _ago, icon: _icon),
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  final AppNotification n;
  final String Function(DateTime) ago;
  final IconData Function(String) icon;
  const _Tile({required this.n, required this.ago, required this.icon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final link = n.link;
        if (link != null && link.startsWith('/')) context.push(link);
      },
      child: Container(
        color: n.read ? null : AppColors.accent.withValues(alpha: .06),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: (n.image != null && n.image!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: n.image!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _IconBox(icon: icon(n.type)),
                    )
                  : _IconBox(icon: icon(n.type)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(n.title,
                            style: TextStyle(
                                fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                                fontSize: 15)),
                      ),
                      if (!n.read)
                        Container(
                          width: 9,
                          height: 9,
                          margin: const EdgeInsets.only(left: 6, top: 4),
                          decoration: const BoxDecoration(
                              color: AppColors.accent, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  if (n.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(n.body, style: const TextStyle(color: AppColors.muted, height: 1.3)),
                  ],
                  const SizedBox(height: 6),
                  Text(ago(n.receivedAt),
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  const _IconBox({required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: AppColors.accent),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.muted),
            SizedBox(height: 12),
            Text('No notifications yet', style: TextStyle(color: AppColors.muted, fontSize: 16)),
          ],
        ),
      );
}
