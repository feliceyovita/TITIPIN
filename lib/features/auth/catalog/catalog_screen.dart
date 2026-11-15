
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.grid_view_rounded,
                size: 60,
                color: AppColors.primary,
              ),
              const SizedBox(height: 16),

              Text(
                'Halaman Katalog',
                style: Theme.of(context).textTheme.headlineSmall,
              ),

              const SizedBox(height: 8),

              const Text(
                'UI Katalog akan dibuat oleh anggota '
                    'yang bertugas pada tahap implementasi berikutnya.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
