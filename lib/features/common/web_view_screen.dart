import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';
import 'trailer_screen.dart';

class WebArgs {
  final String url;
  final String? title;
  const WebArgs({required this.url, this.title});
}

/// Circular play button overlaid on a banner; opens the YouTube trailer player.
/// [url] is the trailer embed/watch URL; the 11-char id is extracted from it.
class TrailerPlayButton extends StatelessWidget {
  final String url;
  final String title;
  const TrailerPlayButton({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final id = youtubeIdFrom(url);
        if (id != null) {
          context.push('/trailer', extra: TrailerArgs(id, title: title));
        }
      },
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: .92),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 16)],
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
      ),
    );
  }
}

/// Simple in-app browser for external banner / promo links.
class WebViewScreen extends StatefulWidget {
  final WebArgs args;
  const WebViewScreen({super.key, required this.args});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.args.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.args.title ?? 'Buleto')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(color: AppColors.accent),
        ],
      ),
    );
  }
}
