import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_config.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(text: 'ticketnepal124@gmail.com');
  final _password = TextEditingController(text: 'password');
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final err = await ref.read(authProvider.notifier).login(_email.text.trim(), _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      _onAuthed();
    } else {
      setState(() => _error = err);
    }
  }

  /// Return to the screen that asked for login (e.g. the seat map); otherwise home.
  void _onAuthed() {
    if (context.canPop()) {
      context.pop(true);
    } else {
      context.go('/home');
    }
  }

  Future<void> _google() async {
    setState(() { _loading = true; _error = null; });
    final err = await ref.read(authProvider.notifier).googleLogin();
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      // Either signed in or the user cancelled.
      if (ref.read(authProvider).status == AuthStatus.authenticated) _onAuthed();
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShaderMask(
                  shaderCallback: (b) => AppColors.accentGradient.createShader(b),
                  child: const Text('BULETO',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: Colors.white)),
                ),
                const SizedBox(height: 6),
                const Text('Welcome back', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 28),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: .12), borderRadius: BorderRadius.circular(8)),
                    child: Text(_error!, style: const TextStyle(color: AppColors.accent)),
                  ),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email')),
                const SizedBox(height: 12),
                TextField(controller: _password, obscureText: true, decoration: const InputDecoration(hintText: 'Password')),
                const SizedBox(height: 20),
                AccentButton(label: 'Log in', loading: _loading, onPressed: _submit),
                if (ApiConfig.googleEnabled) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Continue with Google'),
                    onPressed: _loading ? null : _google,
                  ),
                ],
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => context.push('/forgot'),
                  child: const Text('Forgot password?', style: TextStyle(color: AppColors.muted)),
                ),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text("Don't have an account? Sign up", style: TextStyle(color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
