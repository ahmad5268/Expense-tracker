import 'package:flutter/material.dart';

class AppTheme {
  // Primary colour from design tokens: #4F46E5
  static const _seedColor = Color(0xFF4F46E5);

  // Design token colours
  static const colorIncome = Color(0xFF10B981);
  static const colorExpense = Color(0xFFEF4444);
  static const colorWarning = Color(0xFFF59E0B);
  static const colorBackground = Color(0xFFF1F5F9);
  static const colorSurface = Color(0xFFFFFFFF);
  static const colorSidebar = Color(0xFF0F172A);
  static const colorTextPrimary = Color(0xFF1E293B);
  static const colorTextSecondary = Color(0xFF64748B);
  static const colorTextHint = Color(0xFF94A3B8);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
          background: colorBackground,
          surface: colorSurface,
        ),
        scaffoldBackgroundColor: colorBackground,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardTheme(
          elevation: 0,
          color: colorSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontFamily: 'System UI',
              fontWeight: FontWeight.w700,
              color: colorTextPrimary),
          headlineLarge: TextStyle(
              fontFamily: 'System UI',
              fontWeight: FontWeight.w700,
              color: colorTextPrimary),
          headlineMedium: TextStyle(
              fontFamily: 'System UI',
              fontWeight: FontWeight.w700,
              color: colorTextPrimary),
          titleLarge: TextStyle(
              fontFamily: 'System UI',
              fontWeight: FontWeight.w600,
              color: colorTextPrimary),
          titleMedium: TextStyle(
              fontFamily: 'System UI',
              fontWeight: FontWeight.w600,
              color: colorTextPrimary),
          bodyLarge: TextStyle(
              fontFamily: 'System UI',
              fontWeight: FontWeight.w400,
              color: colorTextPrimary),
          bodyMedium: TextStyle(
              fontFamily: 'System UI',
              fontWeight: FontWeight.w400,
              color: colorTextSecondary),
          bodySmall: TextStyle(
              fontFamily: 'System UI',
              fontWeight: FontWeight.w400,
              color: colorTextHint),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
        cardTheme: CardTheme(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF2C2C2C)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
              fontFamily: 'System UI', fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(
              fontFamily: 'System UI', fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(
              fontFamily: 'System UI', fontWeight: FontWeight.w700),
          titleLarge: TextStyle(
              fontFamily: 'System UI', fontWeight: FontWeight.w600),
          titleMedium: TextStyle(
              fontFamily: 'System UI', fontWeight: FontWeight.w600),
          bodyLarge: TextStyle(
              fontFamily: 'System UI', fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(
              fontFamily: 'System UI', fontWeight: FontWeight.w400),
          bodySmall: TextStyle(
              fontFamily: 'System UI', fontWeight: FontWeight.w400),
        ),
      );
}
