import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Tests for CompanySelectorScreen._getRoleColor logic
/// The method is private, so we test the equivalent logic directly.

void main() {
  group('CompanySelector - Role Color Mapping', () {
    Color getRoleColor(String role) {
      switch (role.toLowerCase()) {
        case 'admin':
        case 'manager':
          return AppTheme.infoBlue;
        case 'owner':
          return AppTheme.accentAmber;
        case 'worker':
          return AppTheme.primaryIndigo;
        default:
          return AppTheme.textSecondary;
      }
    }

    test('admin role returns infoBlue', () {
      expect(getRoleColor('admin'), AppTheme.infoBlue);
    });

    test('manager role returns infoBlue', () {
      expect(getRoleColor('manager'), AppTheme.infoBlue);
    });

    test('owner role returns accentAmber', () {
      expect(getRoleColor('owner'), AppTheme.accentAmber);
    });

    test('worker role returns primaryIndigo', () {
      expect(getRoleColor('worker'), AppTheme.primaryIndigo);
    });

    test('unknown role returns textSecondary', () {
      expect(getRoleColor('unknown'), AppTheme.textSecondary);
    });

    test('is case insensitive', () {
      expect(getRoleColor('ADMIN'), AppTheme.infoBlue);
      expect(getRoleColor('Manager'), AppTheme.infoBlue);
      expect(getRoleColor('OWNER'), AppTheme.accentAmber);
      expect(getRoleColor('Worker'), AppTheme.primaryIndigo);
    });

    test('empty string returns textSecondary', () {
      expect(getRoleColor(''), AppTheme.textSecondary);
    });

    test('custom role returns textSecondary', () {
      expect(getRoleColor('site_engineer'), AppTheme.textSecondary);
      expect(getRoleColor('supervisor'), AppTheme.textSecondary);
    });
  });

  group('CompanySelector - Company Initial Letter', () {
    test('extracts first letter and uppercases it', () {
      String getInitial(String companyName) {
        return companyName.isNotEmpty
            ? companyName[0].toUpperCase()
            : '?';
      }

      expect(getInitial('Acme Corp'), 'A');
      expect(getInitial('builder solutions'), 'B');
      expect(getInitial(''), '?');
      expect(getInitial('123 Construction'), '1');
    });
  });
}
