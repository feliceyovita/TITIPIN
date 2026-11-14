import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Placeholder sementara sampai UI Login berdasarkan Figma dibuat.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_outline, size: 60, color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Halaman Login', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                'UI Login akan dibuat pada tahap implementasi berikutnya.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
