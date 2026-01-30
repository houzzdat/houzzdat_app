import 'package:flutter/material.dart';

/// PHOENIX MODERN INDUSTRIAL THEME
/// Re-engineered for high-glare field environments.
/// Palette: Safety Orange (#EA580C) & Professional Slate (#0F172A)
/// Aesthetic: Optimum Slim Pill with Integrated Transparent Cut-away
class AppTheme {
  AppTheme._();

  // ========== PHOENIX DESIGN TOKENS: COLORS ==========
  static const Color primaryOrange = Color(0xFFEA580C); 
  static const Color slate950 = Color(0xFF020617);
  static const Color slate900 = Color(0xFF0F172A);     // Professional Base
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);      // App Background
  static const Color cardWhite = Colors.white;         // Alias for existing cards
  
  // Functional Status Colors
  static const Color successGreen = Color(0xFF16A34A);
  static const Color infoBlue = Color(0xFF2563EB);
  static const Color errorRed = Color(0xFFDC2626);     // Recording/Disputes
  static const Color amberWarn = Color(0xFFD97706);

  // ========== BACKWARD COMPATIBILITY ALIASES (Legacy Fixes) ==========
  static const Color primaryIndigo = slate900;       // Replaces Indigo with Industrial Slate
  static const Color accentAmber = primaryOrange;    // Replaces Amber with Safety Orange
  static const Color backgroundGrey = slate50;       // Replaces Light Grey with Clean Slate
  static const Color warningOrange = amberWarn;      // Replaces Orange with Industrial Amber
  static const Color textPrimary = slate900;
  static const Color textSecondary = slate500;

  // ========== TYPOGRAPHY: INDUSTRIAL SCALE ==========
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: slate900,
    letterSpacing: -0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: slate900,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
    color: slate900,
  );

  static const TextStyle eyebrow = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w900,
    color: slate400,
    letterSpacing: 1.5,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: slate900,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700, // Heavy weight for better field legibility
    color: slate800,
    height: 1.4,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: slate500,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.bold,
    color: slate400,
  );

  // ========== LAYOUT TOKENS: BENTO & COMMAND ==========
  static const double radiusBento = 24.0;    // Standard for Cards
  static const double radiusM = 16.0;        // Standard for Buttons/Inputs
  static const double radiusS = 12.0;        // For small inner elements
  static const double radiusXL = 40.0;       // For major containers/dialogs
  
  // Legacy Layout Aliases
  static const double radiusL = 24.0; 
  static const double spacingXS = 4.0;       // Added for shared_widgets and action cards
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;      // Large sections
  
  // Elevation Tokens (Industrial Depth)
  static const double elevationLow = 2.0;    // Added for action_card_widget
  static const double elevationMedium = 6.0; // Added for action_card_widget
  
  // Custom Command Bar Geometry
  static const double navBarHeight = 64.0;   // Precise height for the dark pill
  static const double micDiameter = 82.0;    // Optimized for FAB centering
  static const double floatingNavWidth = 0.88; // Industrial pill width ratio
  static const double navBottomMargin = 24.0; // Floating offset from device bottom

  // ========== THEME DATA ==========
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryOrange,
      scaffoldBackgroundColor: slate50,
      
      colorScheme: const ColorScheme.light(
        primary: primaryOrange,
        secondary: slate900,
        surface: Colors.white,
        error: errorRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        surfaceContainerLow: slate50,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: slate900,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 18, 
          fontWeight: FontWeight.w900, 
          letterSpacing: -0.2
        ),
      ),

      // Bento-style Card Theme
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: elevationLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusBento),
          side: const BorderSide(color: slate200, width: 1.2),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // FIX: Resolve "SnackBar presented off screen" error
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.fixed, // Avoids position conflicts with floating pill
        backgroundColor: slate900,
        contentTextStyle: bodyMedium.copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusM)),
        ),
      ),

      // Industrial Button Styles
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryOrange,
          foregroundColor: Colors.white,
          elevation: elevationLow,
          shadowColor: primaryOrange.withOpacity(0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusM)),
          textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
      ),

      // High-Contrast Input Fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusM),
          borderSide: const BorderSide(color: primaryOrange, width: 2),
        ),
        labelStyle: eyebrow,
        contentPadding: const EdgeInsets.all(16),
      ),

      // Global Navigation Setup
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent, // Required to show the custom painter
        elevation: 0,
        selectedItemColor: primaryOrange,
        unselectedItemColor: slate400,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
      ),
    );
  }
}

/// COMMAND BAR WRAPPER
/// This widget provides the layout constraints for the floating pill.
class CommandBarWrapper extends StatelessWidget {
  final Widget child;
  const CommandBarWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Theme(
      // Ensure the child navigation bar doesn't draw a background or clip the dock
      data: Theme.of(context).copyWith(
        canvasColor: Colors.transparent,
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: AppTheme.navBottomMargin),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * AppTheme.floatingNavWidth,
            height: AppTheme.navBarHeight,
            child: CustomPaint(
              painter: NavPodPainter(color: AppTheme.slate900),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper: Custom Painter for the Optimum Cut-away Navigation Bar
class NavPodPainter extends CustomPainter {
  final Color color;
  NavPodPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const double cornerRadius = 32.0; 
    // Optimized notch radius for standard FloatingActionButtonLocation.centerDocked
    const double notchRadius = 46.0; 

    final path = Path()
      ..moveTo(cornerRadius, 0)
      // Top edge with Integrated Cut-away hole logic
      ..lineTo(size.width / 2 - notchRadius, 0)
      ..arcToPoint(
        Offset(size.width / 2 + notchRadius, 0),
        radius: const Radius.circular(notchRadius),
        clockwise: false,
      )
      ..lineTo(size.width - cornerRadius, 0)
      ..arcToPoint(Offset(size.width, cornerRadius), radius: const Radius.circular(cornerRadius))
      ..lineTo(size.width, size.height - cornerRadius)
      ..arcToPoint(Offset(size.width - cornerRadius, size.height), radius: const Radius.circular(cornerRadius))
      ..lineTo(cornerRadius, size.height)
      ..arcToPoint(Offset(0, size.height - cornerRadius), radius: const Radius.circular(cornerRadius))
      ..lineTo(0, cornerRadius)
      ..arcToPoint(Offset(cornerRadius, 0), radius: const Radius.circular(cornerRadius))
      ..close();

    canvas.drawShadow(path.shift(const Offset(0, 8)), Colors.black.withOpacity(0.4), 20.0, true);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}