import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF314959);
  static const gold = Color(0xFFCDAD7D);
  static const lightGray = Color(0xFFA9B7BB);
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF7F8F9);
  static const text = Color(0xFF17242C);
  static const muted = Color(0xFF6B7B83);
  static const success = Color(0xFF2E7D32);
  static const error = Color(0xFFC62828);
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        textTheme: GoogleFonts.cairoTextTheme(),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.text,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          filled: true,
          fillColor: AppColors.surface,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      );
}
