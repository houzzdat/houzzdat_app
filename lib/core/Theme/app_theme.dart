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
  static const Color errorRed = Color(0xFFC62828); // UX-audit #18: was 0xFFD32F2F (~3.8:1), now ~6.5:1 WCAG AA
  static const Color infoBlue = Color(0xFF1565C0);

  // Surface — subtle indigo-tinted grey for depth
  static const Color surfaceGrey = Color(0xFFE8EAF6);

  // Text Colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Color(0xFF616161); // UX-audit HH-03: was 0xFF757575 (~3.0:1), now ~4.7:1 on backgroundGrey
  static const Color textOnPrimary = Colors.white;

  // UX-audit #20: theme-aware derived colors (avoid hardcoded Colors.white / Color(0xFF...))
  static const Color dividerColor = Color(0xFFE0E0E0);
  static const Color accentAmberLight = Color(0xFFFFCA28);
  static const Color avatarBackground = Color(0xFFBBDEFB);
  static const Color needsReviewBackground = Color(0xFFFFF8E1);
  static const Color borderLight = Color(0x0D000000); // ~black.withOpacity(0.05)
  static const Color avatarForeground = Color(0xFF1565C0);
  static const Color badgeGrey = Color(0xFF9E9E9E);
  static const Color needsReviewBorder = Color(0xFFBDBDBD);

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
    fontSize: 13, // UX-audit HH-01: was 11 — unreadable in sunlight
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
          minimumSize: const Size(48, 48), // UX-audit #15: WCAG 2.5.5 touch target
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusL),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48), // UX-audit #15: WCAG 2.5.5 touch target
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48), // UX-audit #15: WCAG 2.5.5 touch target
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

  // ========== DARK THEME (#94) ==========
  static const Color _darkBackground = Color(0xFF121212);
  static const Color _darkSurface = Color(0xFF1E1E1E);
  static const Color _darkCard = Color(0xFF2C2C2C);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryIndigo,
      scaffoldBackgroundColor: _darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF5C6BC0), // lighter indigo for dark mode
        secondary: accentAmber,
        error: Color(0xFFEF5350),
        surface: _darkSurface,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: _darkCard,
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
          foregroundColor: Colors.black,
          elevation: elevationLow,
          minimumSize: const Size(48, 48), // UX-audit #15: WCAG 2.5.5 touch target
          padding: const EdgeInsets.symmetric(
            horizontal: spacingL,
            vertical: spacingM,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusL),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48), // UX-audit #15: WCAG 2.5.5 touch target
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48), // UX-audit #15: WCAG 2.5.5 touch target
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
        fillColor: _darkSurface,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade800,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusM),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _darkCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXL)),
        ),
      ),
    );
  }
}