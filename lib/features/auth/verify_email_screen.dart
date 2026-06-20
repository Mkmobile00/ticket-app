import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

/// Mandatory email verification. A 6-digit code is emailed; the user cannot
/// continue into the app until they enter the correct one. Wrong/empty code
/// is rejected and the router keeps them on this screen.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  bool _sending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    // Email a fresh code as soon as we land here.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode(initial: true));
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool initial = false}) async {
    setState(() { _sending = true; _error = null; _info = null; });
    try {
      final msg = await ref.read(apiProvider).sendEmailVerification();
      if (mounted) setState(() => _info = initial ? 'We sent a 6-digit code to your email and phone.' : msg);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not send the code. Try "Resend".');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code from your email or SMS.');
      return; // can't proceed without typing the code
    }
    setState(() { _loading = true; _error = null; _info = null; });
    try {
      await ref.read(apiProvider).verifyEmail(code);
      // Refresh the user so emailVerified = true, then the router lets us in.
      await ref.read(authProvider.notifier).refresh();
      if (!mounted) return;
      if (ref.read(authProvider).user?.emailVerified == true) {
        context.go('/home');
      } else {
        setState(() => _error = 'Verification did not complete. Try again.');
      }
    } catch (e) {
      // Wrong/expired code → stay put.
      if (mounted) setState(() => _error = 'Invalid or expired code. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authProvider).user?.email ?? 'your email';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 56, color: AppColors.accent),
                const SizedBox(height: 12),
                const Text('Verify your email',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text)),
                const SizedBox(height: 6),
                Text('Enter the 6-digit code sent to\n$email',
                    textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 24),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.accent)),
                  ),
                if (_info != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
                    child: Text(_info!, style: const TextStyle(color: Colors.green)),
                  ),
                TextField(
                  controller: _code,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(hintText: '••••••', counterText: ''),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 16),
                AccentButton(label: 'Verify & continue', loading: _loading, onPressed: _verify),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: _sending ? null : () => _sendCode(),
                  child: Text(_sending ? 'Sending…' : 'Resend code', style: const TextStyle(color: AppColors.muted)),
                ),
                TextButton(
                  onPressed: () async {
                    await ref.read(authProvider.notifier).logout();
                    if (context.mounted) context.go('/login');
                  },
                  child: const Text('Use a different account', style: TextStyle(color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
