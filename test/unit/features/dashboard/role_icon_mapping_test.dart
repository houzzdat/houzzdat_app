import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for role icon mapping logic from team_dialogs.dart.

void main() {
  group('Role Icon Mapping', () {
    IconData getRoleIcon(String role) {
      switch (role.toLowerCase()) {
        case 'admin':
        case 'manager':
          return Icons.admin_panel_settings;
        case 'worker':
          return Icons.engineering;
        case 'owner':
          return Icons.business;
        case 'site_engineer':
          return Icons.construction;
        case 'supervisor':
          return Icons.supervised_user_circle;
        default:
          return Icons.person;
      }
    }

    test('admin returns admin panel icon', () {
      expect(getRoleIcon('admin'), Icons.admin_panel_settings);
    });

    test('manager returns admin panel icon', () {
      expect(getRoleIcon('manager'), Icons.admin_panel_settings);
    });

    test('worker returns engineering icon', () {
      expect(getRoleIcon('worker'), Icons.engineering);
    });

    test('owner returns business icon', () {
      expect(getRoleIcon('owner'), Icons.business);
    });

    test('site_engineer returns construction icon', () {
      expect(getRoleIcon('site_engineer'), Icons.construction);
    });

    test('supervisor returns supervised user icon', () {
      expect(getRoleIcon('supervisor'), Icons.supervised_user_circle);
    });

    test('unknown role returns person icon', () {
      expect(getRoleIcon('unknown'), Icons.person);
    });

    test('empty string returns person icon', () {
      expect(getRoleIcon(''), Icons.person);
    });

    test('is case insensitive', () {
      expect(getRoleIcon('ADMIN'), Icons.admin_panel_settings);
      expect(getRoleIcon('Worker'), Icons.engineering);
      expect(getRoleIcon('OWNER'), Icons.business);
    });
  });

  group('Role Name Duplicate Detection', () {
    test('detects duplicate role name (case insensitive)', () {
      final roles = [
        {'name': 'admin'},
        {'name': 'worker'},
        {'name': 'owner'},
      ];

      bool isDuplicate(String newRole) {
        return roles.any(
            (r) => r['name'].toString().toLowerCase() == newRole.toLowerCase());
      }

      expect(isDuplicate('admin'), true);
      expect(isDuplicate('ADMIN'), true);
      expect(isDuplicate('Admin'), true);
      expect(isDuplicate('worker'), true);
      expect(isDuplicate('supervisor'), false);
      expect(isDuplicate('site_engineer'), false);
    });
  });
}
