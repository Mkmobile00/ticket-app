import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Centered spinner.
class Loading extends StatelessWidget {
  const Loading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.accent));
}

/// Error state with a retry button.
class ErrorRetry extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;
  const ErrorRetry({super.key, required this.onRetry, this.message = "Couldn't reach the server.\nIs the API running?"});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, color: AppColors.muted, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Empty placeholder.
class EmptyView extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyView({super.key, required this.message, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.muted, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Network image with rounded corners + graceful fallback.
class RoundedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;
  const RoundedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.radius = 12,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (_, __) => Container(color: AppColors.surface2),
        errorWidget: (_, __, ___) =>
            Container(color: AppColors.surface2, child: const Icon(Icons.image_not_supported, color: AppColors.muted)),
      ),
    );
  }
}

/// 2:3 poster with a title beneath, used in horizontal rails and grids.
class PosterTile extends StatelessWidget {
  final String image;
  final String title;
  final String? subtitle;
  final double? rating;
  final VoidCallback? onTap;
  const PosterTile({
    super.key,
    required this.image,
    required this.title,
    this.subtitle,
    this.rating,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 2 / 3,
            child: RoundedImage(url: image, width: double.infinity),
          ),
          const SizedBox(height: 6),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (rating != null && rating! > 0)
            Text('★ ${rating!.toStringAsFixed(1)}', style: const TextStyle(color: AppColors.accent, fontSize: 12)),
          if (subtitle != null)
            Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Small chip for genres/languages/formats.
class TagChip extends StatelessWidget {
  final String label;
  const TagChip(this.label, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.text)),
    );
  }
}

/// Quick snackbar helper.
void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.seatBooked : AppColors.surface2,
      behavior: SnackBarBehavior.floating,
    ));
}
