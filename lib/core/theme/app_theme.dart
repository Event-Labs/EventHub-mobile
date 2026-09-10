import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        background: AppColors.background,
        onBackground: AppColors.onSurface,
        error: AppColors.error,
        outline: AppColors.outline,
      ),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'Geist',
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.72,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'Geist',
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.42,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'Geist',
            fontSize: 24,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.24,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'Geist',
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          titleLarge: TextStyle(
            fontFamily: 'Geist',
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.24,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.44,
          ),
        ),
      ),
    );
  }
}
