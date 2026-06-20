import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await ref.read(apiProvider).forgotPassword(_email.text.trim());
      if (!mounted) return;
      setState(() => _codeSent = true);
      showSnack(context, msg);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await ref.read(apiProvider).resetPassword(
            identifier: _email.text.trim(),
            code: _code.text.trim(),
            password: _password.text,
          );
      if (!mounted) return;
      showSnack(context, msg);
      context.go('/login');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _codeSent
                    ? 'Enter the 6-digit code we sent to your email & phone, then choose a new password.'
                    : "Enter your email or phone number and we'll send a reset code.",
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(_error!, style: const TextStyle(color: AppColors.accent)),
                ),
              TextField(
                controller: _email,
                enabled: !_codeSent,
                keyboardType: TextInputType.text,
                decoration: const InputDecoration(hintText: 'Email or phone number'),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                TextField(controller: _code, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: '6-digit code')),
                const SizedBox(height: 12),
                TextField(controller: _password, obscureText: true, decoration: const InputDecoration(hintText: 'New password (min 8 chars)')),
              ],
              const SizedBox(height: 20),
              AccentButton(
                label: _codeSent ? 'Reset password' : 'Send code',
                loading: _busy,
                onPressed: _codeSent ? _reset : _sendCode,
              ),
              if (_codeSent)
                TextButton(
                  onPressed: _busy ? null : _sendCode,
                  child: const Text('Resend code', style: TextStyle(color: AppColors.muted)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
