import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Bootstrap auth; the router's redirect sends us to /home or /login.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ShaderMask(
              shaderCallback: (b) => AppColors.accentGradient.createShader(b),
              child: const Text('BULETO',
                  style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
            ),
            const SizedBox(height: 18),
            const CircularProgressIndicator(color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}
