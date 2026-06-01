import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/theme/app_theme.dart';

class PaymentWebViewArgs {
  final int bookingId;
  final String gateway;
  final String? redirect;
  final Map<String, dynamic>? form;
  const PaymentWebViewArgs({
    required this.bookingId,
    required this.gateway,
    this.redirect,
    this.form,
  });
}

/// Hosts the eSewa / Khalti payment page. Pops `true` once the gateway
/// redirects back to our /payment/callback/{id} URL.
class PaymentWebViewScreen extends StatefulWidget {
  final PaymentWebViewArgs args;
  const PaymentWebViewScreen({super.key, required this.args});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _done = false;

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
        onNavigationRequest: (req) {
          if (req.url.contains('/payment/callback/')) {
            _finish(true);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));
    _start();
  }

  void _start() {
    final form = widget.args.form;
    if (form != null && form['action'] != null) {
      // Build a self-submitting HTML form for gateways that need a POST.
      final action = form['action'].toString();
      final fields = Map<String, dynamic>.from(form['fields'] ?? {});
      final inputs = fields.entries
          .map((e) => '<input type="hidden" name="${e.key}" value="${e.value}">')
          .join();
      final html = '''
<!DOCTYPE html><html><body onload="document.forms[0].submit()">
<form action="$action" method="POST">$inputs</form>
<p style="font-family:sans-serif">Redirecting to ${widget.args.gateway}…</p>
</body></html>''';
      _controller.loadHtmlString(html);
    } else if (widget.args.redirect != null) {
      _controller.loadRequest(Uri.parse(widget.args.redirect!));
    } else {
      // Nothing to load; let the user confirm manually.
      if (mounted) setState(() => _loading = false);
    }
  }

  void _finish(bool paid) {
    if (_done) return;
    _done = true;
    if (mounted) context.pop(paid);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish(false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Pay with ${widget.args.gateway}'),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: () => _finish(false)),
          actions: [
            TextButton(
              onPressed: () => _finish(true),
              child: const Text("I've paid", style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (widget.args.redirect != null || widget.args.form != null)
              WebViewWidget(controller: _controller)
            else
              const Center(child: Text('Complete the payment, then tap the button above.')),
            if (_loading) const LinearProgressIndicator(color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
