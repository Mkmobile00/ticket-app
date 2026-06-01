import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../common/widgets.dart';

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_password.text != _confirm.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final msg = await ref.read(apiProvider).changePassword(current: _current.text, password: _password.text);
      if (!mounted) return;
      showSnack(context, msg);
      context.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(_error!, style: const TextStyle(color: AppColors.accent)),
            ),
          TextField(controller: _current, obscureText: true, decoration: const InputDecoration(hintText: 'Current password')),
          const SizedBox(height: 12),
          TextField(controller: _password, obscureText: true, decoration: const InputDecoration(hintText: 'New password (min 8 chars)')),
          const SizedBox(height: 12),
          TextField(controller: _confirm, obscureText: true, decoration: const InputDecoration(hintText: 'Confirm new password')),
          const SizedBox(height: 20),
          AccentButton(label: 'Update password', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}
