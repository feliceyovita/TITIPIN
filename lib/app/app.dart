import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../features/splash/presentation/splash_screen.dart';

class TitipinApp extends StatelessWidget {
  const TitipinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Titipin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
