import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Warna utama aplikasi
  static const Color primary = Color(0xFF668B72);
  static const Color background = Color(0xFFF3F6FB);

  // Warna komponen
  static const Color inputBorder = Color(0xFFE1E6EC);
  static const Color inputBackground = Color(0xFFFBFCFE);

  // Warna teks
  static const Color textPrimary = Color(0xFF526071);
  static const Color textSecondary = Color(0xFF788493);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
}