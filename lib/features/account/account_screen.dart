import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_service.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';
import '../common/notification_bell.dart';
import '../common/widgets.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _fill() {
    final u = ref.read(authProvider).user;
    if (u != null && !_loaded) {
      _name.text = u.name;
      _email.text = u.email;
      _phone.text = u.phone ?? '';
      _loaded = true;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiProvider).updateProfile(
            name: _name.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
          );
      await ref.read(authProvider.notifier).refresh();
      if (mounted) showSnack(context, 'Profile updated.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _verifyEmail() async {
    try {
      await ref.read(apiProvider).sendEmailVerification();
      if (!mounted) return;
      final code = await _promptCode('Verify email', 'Enter the 6-digit code sent to your email.');
      if (code == null || code.isEmpty) return;
      await ref.read(apiProvider).verifyEmail(code);
      await ref.read(authProvider.notifier).refresh();
      if (mounted) showSnack(context, 'Email verified.');
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  Future<String?> _promptCode(String title, String hint) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Verify')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    _fill();

    return Scaffold(
      appBar: AppBar(title: const Text('Account'), actions: const [NotificationBell()]),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.surface2,
                  child: Text(
                    (user?.name.isNotEmpty == true ? user!.name[0] : '?').toUpperCase(),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.accent),
                  ),
                ),
                const SizedBox(height: 12),
                Text(user?.name ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                Text(user?.email ?? '', style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (user != null && !user.emailVerified)
            Card(
              color: AppColors.seatLocked.withValues(alpha: .15),
              child: ListTile(
                leading: const Icon(Icons.mark_email_unread_outlined, color: AppColors.seatLocked),
                title: const Text('Verify your email'),
                subtitle: const Text('Tap to receive a verification code'),
                onTap: _verifyEmail,
              ),
            ),
          const SizedBox(height: 12),
          const Text('Profile', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          TextField(controller: _name, decoration: const InputDecoration(hintText: 'Full name')),
          const SizedBox(height: 12),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Email')),
          const SizedBox(height: 12),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(hintText: 'Phone')),
          const SizedBox(height: 16),
          AccentButton(label: 'Save changes', loading: _saving, onPressed: _save),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change password'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => context.push('/account/password'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.confirmation_number_outlined),
                  title: const Text('My bookings'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => context.go('/bookings'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/home');
            },
          ),
        ],
      ),
    );
  }
}
