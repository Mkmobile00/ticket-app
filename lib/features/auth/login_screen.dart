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
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signup = false;
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final auth = ref.read(authProvider.notifier);
    final err = _signup
        ? await auth.register(_name.text.trim(), _email.text.trim(), _password.text, null)
        : await auth.login(_email.text.trim(), _password.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      _onAuthed();
    } else {
      setState(() => _error = err);
    }
  }

  void _onAuthed() {
    if (_signup) { context.go('/home'); return; }
    if (context.canPop()) { context.pop(true); } else { context.go('/home'); }
  }

  Future<void> _google() async {
    if (!ApiConfig.googleEnabled) {
      setState(() => _error = 'Google sign-in is not configured yet.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    final err = await ref.read(authProvider.notifier).googleLogin();
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      if (ref.read(authProvider).status == AuthStatus.authenticated) _onAuthed();
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(gradient: AppColors.accentGradient, borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.confirmation_num_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 22),
              const Text('Welcome to BULETO', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.5, color: AppColors.text)),
              const SizedBox(height: 6),
              const Text('Book movies, events & sports in seconds.', style: TextStyle(fontSize: 14.5, color: AppColors.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 22),

              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(color: AppColors.surface2, borderRadius: BorderRadius.circular(16)),
                child: Row(children: [
                  _seg('Sign in', !_signup, () => setState(() { _signup = false; _error = null; })),
                  _seg('Sign up', _signup, () => setState(() { _signup = true; _error = null; })),
                ]),
              ),
              const SizedBox(height: 22),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(color: const Color(0x1AE5484D), borderRadius: BorderRadius.circular(10)),
                  child: Text(_error!, style: const TextStyle(color: Color(0xFFE5484D), fontWeight: FontWeight.w600)),
                ),

              if (_signup) ...[
                _label('Full name'),
                _field(_name, 'Your name', Icons.person_outline),
                const SizedBox(height: 16),
              ],
              _label('Email'),
              _field(_email, 'you@example.com', Icons.mail_outline, keyboard: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _label('Password'),
              _field(_password, '••••••••', Icons.lock_outline, obscure: _obscure, suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.muted, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              )),

              if (!_signup)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot'),
                    child: const Text('Forgot password?', style: TextStyle(color: AppColors.accent2, fontWeight: FontWeight.w700)),
                  ),
                ),
              const SizedBox(height: 8),

              GestureDetector(
                onTap: _loading ? null : _submit,
                child: Container(
                  height: 56, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.line),
                    boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: .12), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: _loading
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(_signup ? 'Create account' : 'Sign in', style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, size: 18, color: AppColors.text),
                        ]),
                ),
              ),
              const SizedBox(height: 18),

              const Text('or continue with', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _social('G', 'Google', const Color(0xFFEA4335), _google)),
                const SizedBox(width: 12),
                Expanded(child: _social('', 'Apple', AppColors.text, () => setState(() => _error = 'Apple sign-in coming soon.'), apple: true)),
              ]),
              const SizedBox(height: 18),
              const Text.rich(
                TextSpan(
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                  children: [
                    TextSpan(text: "By continuing you agree to BULETO's "),
                    TextSpan(text: 'Terms', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                    TextSpan(text: ' & '),
                    TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700)),
                    TextSpan(text: '.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seg(String label, bool active, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 8, offset: const Offset(0, 2))] : null,
            ),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: active ? AppColors.text : AppColors.muted)),
          ),
        ),
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.text)),
      );

  Widget _field(TextEditingController c, String hint, IconData icon,
      {bool obscure = false, TextInputType? keyboard, Widget? suffix}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      keyboardType: keyboard,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.muted, size: 20),
        suffixIcon: suffix,
      ),
    );
  }

  Widget _social(String letter, String label, Color color, VoidCallback onTap, {bool apple = false}) {
    return GestureDetector(
      onTap: _loading ? null : onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.line)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          apple
              ? const Icon(Icons.apple, size: 22, color: AppColors.text)
              : Container(width: 22, height: 22, alignment: Alignment.center,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
                  child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
          const SizedBox(width: 9),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text, fontSize: 14.5)),
        ]),
      ),
    );
  }
}
