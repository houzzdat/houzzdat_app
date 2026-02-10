import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

void main() {
  group('AppTheme Colors', () {
    test('primaryIndigo is correct hex', () {
      expect(AppTheme.primaryIndigo, const Color(0xFF1A237E));
    });

    test('accentAmber is correct hex', () {
      expect(AppTheme.accentAmber, const Color(0xFFFFC107));
    });

    test('status colors are distinct', () {
      expect(AppTheme.successGreen, isNot(equals(AppTheme.errorRed)));
      expect(AppTheme.warningOrange, isNot(equals(AppTheme.infoBlue)));
      expect(AppTheme.errorRed, isNot(equals(AppTheme.successGreen)));
    });

    test('successGreen is correct hex', () {
      expect(AppTheme.successGreen, const Color(0xFF2E7D32));
    });

    test('warningOrange is correct hex', () {
      expect(AppTheme.warningOrange, const Color(0xFFEF6C00));
    });

    test('errorRed is correct hex', () {
      expect(AppTheme.errorRed, const Color(0xFFD32F2F));
    });

    test('infoBlue is correct hex', () {
      expect(AppTheme.infoBlue, const Color(0xFF1565C0));
    });

    test('text colors are defined', () {
      expect(AppTheme.textPrimary, Colors.black87);
      expect(AppTheme.textOnPrimary, Colors.white);
      expect(AppTheme.textSecondary, const Color(0xFF757575));
    });

    test('cardWhite is white', () {
      expect(AppTheme.cardWhite, Colors.white);
    });
  });

  group('AppTheme Typography', () {
    test('headingLarge has correct properties', () {
      expect(AppTheme.headingLarge.fontSize, 24);
      expect(AppTheme.headingLarge.fontWeight, FontWeight.bold);
      expect(AppTheme.headingLarge.color, AppTheme.textPrimary);
    });

    test('headingMedium has correct properties', () {
      expect(AppTheme.headingMedium.fontSize, 18);
      expect(AppTheme.headingMedium.fontWeight, FontWeight.bold);
    });

    test('headingSmall has correct properties', () {
      expect(AppTheme.headingSmall.fontSize, 16);
      expect(AppTheme.headingSmall.fontWeight, FontWeight.bold);
    });

    test('bodyLarge has correct size', () {
      expect(AppTheme.bodyLarge.fontSize, 16);
    });

    test('bodyMedium has correct size', () {
      expect(AppTheme.bodyMedium.fontSize, 14);
    });

    test('bodySmall has correct size and color', () {
      expect(AppTheme.bodySmall.fontSize, 12);
      expect(AppTheme.bodySmall.color, AppTheme.textSecondary);
    });

    test('caption has correct size', () {
      expect(AppTheme.caption.fontSize, 11);
      expect(AppTheme.caption.color, AppTheme.textSecondary);
    });

    test('font sizes follow hierarchy', () {
      expect(AppTheme.headingLarge.fontSize!,
          greaterThan(AppTheme.headingMedium.fontSize!));
      expect(AppTheme.headingMedium.fontSize!,
          greaterThanOrEqualTo(AppTheme.headingSmall.fontSize!));
      expect(AppTheme.bodyLarge.fontSize!,
          greaterThan(AppTheme.bodyMedium.fontSize!));
      expect(AppTheme.bodyMedium.fontSize!,
          greaterThan(AppTheme.bodySmall.fontSize!));
      expect(AppTheme.bodySmall.fontSize!,
          greaterThan(AppTheme.caption.fontSize!));
    });
  });

  group('AppTheme Spacing', () {
    test('spacing values are in ascending order', () {
      expect(AppTheme.spacingXS, lessThan(AppTheme.spacingS));
      expect(AppTheme.spacingS, lessThan(AppTheme.spacingM));
      expect(AppTheme.spacingM, lessThan(AppTheme.spacingL));
      expect(AppTheme.spacingL, lessThan(AppTheme.spacingXL));
    });

    test('spacing XS is 4', () {
      expect(AppTheme.spacingXS, 4.0);
    });

    test('spacing S is 8', () {
      expect(AppTheme.spacingS, 8.0);
    });

    test('spacing M is 16', () {
      expect(AppTheme.spacingM, 16.0);
    });

    test('spacing L is 24', () {
      expect(AppTheme.spacingL, 24.0);
    });

    test('spacing XL is 32', () {
      expect(AppTheme.spacingXL, 32.0);
    });
  });

  group('AppTheme Border Radius', () {
    test('radius values are in ascending order', () {
      expect(AppTheme.radiusS, lessThan(AppTheme.radiusM));
      expect(AppTheme.radiusM, lessThan(AppTheme.radiusL));
      expect(AppTheme.radiusL, lessThan(AppTheme.radiusXL));
    });

    test('radius S is 4', () {
      expect(AppTheme.radiusS, 4.0);
    });

    test('radius M is 8', () {
      expect(AppTheme.radiusM, 8.0);
    });

    test('radius L is 12', () {
      expect(AppTheme.radiusL, 12.0);
    });

    test('radius XL is 16', () {
      expect(AppTheme.radiusXL, 16.0);
    });
  });

  group('AppTheme Elevation', () {
    test('elevation values are in ascending order', () {
      expect(AppTheme.elevationLow, lessThan(AppTheme.elevationMedium));
      expect(AppTheme.elevationMedium, lessThan(AppTheme.elevationHigh));
    });

    test('elevation values', () {
      expect(AppTheme.elevationLow, 2.0);
      expect(AppTheme.elevationMedium, 4.0);
      expect(AppTheme.elevationHigh, 8.0);
    });
  });

  group('AppTheme lightTheme', () {
    test('lightTheme returns valid ThemeData', () {
      final theme = AppTheme.lightTheme;
      expect(theme, isA<ThemeData>());
    });

    test('lightTheme has correct primary color', () {
      final theme = AppTheme.lightTheme;
      expect(theme.primaryColor, AppTheme.primaryIndigo);
    });

    test('lightTheme has correct scaffold background', () {
      final theme = AppTheme.lightTheme;
      expect(theme.scaffoldBackgroundColor, AppTheme.backgroundGrey);
    });

    test('lightTheme color scheme uses correct colors', () {
      final scheme = AppTheme.lightTheme.colorScheme;
      expect(scheme.primary, AppTheme.primaryIndigo);
      expect(scheme.secondary, AppTheme.accentAmber);
      expect(scheme.error, AppTheme.errorRed);
      expect(scheme.surface, AppTheme.cardWhite);
    });

    test('lightTheme AppBar has no elevation', () {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.elevation, 0);
    });

    test('lightTheme AppBar uses primary color', () {
      final theme = AppTheme.lightTheme;
      expect(theme.appBarTheme.backgroundColor, AppTheme.primaryIndigo);
      expect(theme.appBarTheme.foregroundColor, AppTheme.textOnPrimary);
    });

    test('lightTheme SnackBar has floating behavior', () {
      final theme = AppTheme.lightTheme;
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    });

    test('lightTheme card has correct elevation', () {
      final theme = AppTheme.lightTheme;
      expect(theme.cardTheme.elevation, AppTheme.elevationLow);
    });
  });
}
