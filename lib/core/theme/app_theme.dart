import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    final darkBase = ThemeData.dark(useMaterial3: true);

    TextTheme baseTextTheme = darkBase.textTheme.copyWith(
      displayLarge: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -0.72, color: Colors.white),
      headlineLarge: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.42, color: Colors.white),
      headlineMedium: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.24, color: Colors.white),
      headlineSmall: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: Colors.white),
      titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
      bodyLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: Colors.white),
      bodyMedium: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: Colors.white70),
      labelLarge: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.24, color: Colors.white),
      labelSmall: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.44, color: Colors.white60),
    );

    TextTheme textTheme;
    try {
      textTheme = GoogleFonts.interTextTheme(baseTextTheme);
    } catch (_) {
      textTheme = baseTextTheme;
    }

    String? fontFamily;
    try {
      fontFamily = GoogleFonts.inter().fontFamily;
    } catch (_) {}

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      fontFamilyFallback: const ['Roboto', 'sans-serif'],
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        error: AppColors.error,
        outline: AppColors.outline,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
    );
  }
}
