import 'package:flutter/material.dart';

/// Centralized theme configuration for the entire app
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // ========== COLORS ==========
  static const Color primaryIndigo = Color(0xFF1A237E);
  static const Color accentAmber = Color(0xFFFFC107);
  static const Color backgroundGrey = Color(0xFFF4F4F4);
  static const Color cardWhite = Colors.white;
  
  // Status Colors — softer, professional tones
  static const Color successGreen = Color(0xFF2E7D32);
  static const Color warningOrange = Color(0xFFEF6C00);
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color infoBlue = Color(0xFF1565C0);

  // Surface — subtle indigo-tinted grey for depth
  static const Color surfaceGrey = Color(0xFFE8EAF6);

  // Text Colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Colors.white;

  // ========== TYPOGRAPHY ==========
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: textPrimary,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: textPrimary,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: textPrimary,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    color: textSecondary,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    color: textSecondary,
  );

  // ========== SPACING ==========
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  // ========== BORDER RADIUS ==========
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;

  // ========== ELEVATION ==========
  static const double elevationLow = 2.0;
  static const double elevationMedium = 4.0;
  static const double elevationHigh = 8.0;

  // ========== THEME DATA ==========
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryIndigo,
      scaffoldBackgroundColor: backgroundGrey,
      colorScheme: const ColorScheme.light(
        primary: primaryIndigo,
        secondary: accentAmber,
        error: errorRed,
        surface: cardWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryIndigo,
        foregroundColor: textOnPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: cardWhite,
        elevation: elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusL),
        ),
        margin: const EdgeInsets.symmetric(
          horizontal: spacingM,
          vertical: spacingS,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentAmber,
          foregroundColor: textPrimary,
          elevation: elevationLow,
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusL),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingM,
          vertical: spacingM,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade300,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),
    );
  }
}