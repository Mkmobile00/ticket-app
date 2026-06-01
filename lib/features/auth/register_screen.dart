import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() { _loading = true; _error = null; });
    final err = await ref.read(authProvider.notifier).register(
          _name.text.trim(), _email.text.trim(), _password.text, _phone.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      context.go('/home');
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null)
                Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(_error!, style: const TextStyle(color: AppColors.accent))),
              TextField(controller: _name, decoration: const InputDecoration(hintText: 'Full name')),
              const SizedBox(height: 12),
              TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email')),
              const SizedBox(height: 12),
              TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Phone (optional)')),
              const SizedBox(height: 12),
              TextField(controller: _password, obscureText: true, decoration: const InputDecoration(hintText: 'Password (min 8 chars)')),
              const SizedBox(height: 20),
              AccentButton(label: 'Sign up', loading: _loading, onPressed: _submit),
              const SizedBox(height: 12),
              TextButton(onPressed: () => context.go('/login'), child: const Text('Already have an account? Log in', style: TextStyle(color: AppColors.muted))),
            ],
          ),
        ),
      ),
    );
  }
}
