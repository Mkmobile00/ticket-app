import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';

class WebArgs {
  final String url;
  final String? title;
  const WebArgs({required this.url, this.title});
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
