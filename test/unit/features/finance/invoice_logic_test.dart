import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for InvoiceCard business logic patterns.

void main() {
  group('Invoice - Status Color Mapping', () {
    Color statusColor(String status) {
      switch (status) {
        case 'draft':
          return Colors.grey;
        case 'submitted':
          return const Color(0xFF1565C0); // infoBlue
        case 'approved':
          return const Color(0xFF2E7D32); // successGreen
        case 'rejected':
          return const Color(0xFFD32F2F); // errorRed
        case 'paid':
          return const Color(0xFF2E7D32); // successGreen
        case 'overdue':
          return const Color(0xFFD32F2F); // errorRed
        default:
          return Colors.grey;
      }
    }

    test('maps all valid statuses', () {
      expect(statusColor('draft'), Colors.grey);
      expect(statusColor('submitted'), const Color(0xFF1565C0));
      expect(statusColor('approved'), const Color(0xFF2E7D32));
      expect(statusColor('rejected'), const Color(0xFFD32F2F));
      expect(statusColor('paid'), const Color(0xFF2E7D32));
      expect(statusColor('overdue'), const Color(0xFFD32F2F));
    });

    test('approved and paid share same color', () {
      expect(statusColor('approved'), statusColor('paid'));
    });

    test('rejected and overdue share same color', () {
      expect(statusColor('rejected'), statusColor('overdue'));
    });

    test('unknown status defaults to grey', () {
      expect(statusColor('cancelled'), Colors.grey);
      expect(statusColor(''), Colors.grey);
    });
  });

  group('Invoice - Payment Progress Calculation', () {
    test('calculates 50% progress', () {
      const amount = 10000.0;
      final payments = [
        {'amount': 5000},
      ];
      final totalPaid = payments.fold<double>(
        0,
        (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
      );
      final progress =
          amount > 0 ? (totalPaid / amount).clamp(0.0, 1.0) : 0.0;

      expect(totalPaid, 5000.0);
      expect(progress, 0.5);
    });

    test('calculates 100% progress', () {
      const amount = 10000.0;
      final payments = [
        {'amount': 7000},
        {'amount': 3000},
      ];
      final totalPaid = payments.fold<double>(
        0,
        (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
      );
      final progress =
          amount > 0 ? (totalPaid / amount).clamp(0.0, 1.0) : 0.0;

      expect(totalPaid, 10000.0);
      expect(progress, 1.0);
    });

    test('clamps overpayment to 100%', () {
      const amount = 10000.0;
      final payments = [
        {'amount': 15000},
      ];
      final totalPaid = payments.fold<double>(
        0,
        (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
      );
      final progress =
          amount > 0 ? (totalPaid / amount).clamp(0.0, 1.0) : 0.0;

      expect(progress, 1.0);
    });

    test('returns 0% for no payments', () {
      const amount = 10000.0;
      final payments = <Map<String, dynamic>>[];
      final totalPaid = payments.fold<double>(
        0,
        (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
      );
      final progress =
          amount > 0 ? (totalPaid / amount).clamp(0.0, 1.0) : 0.0;

      expect(progress, 0.0);
    });

    test('handles zero invoice amount', () {
      const amount = 0.0;
      final progress = amount > 0 ? (5000 / amount).clamp(0.0, 1.0) : 0.0;

      expect(progress, 0.0);
    });

    test('handles null amount in payment', () {
      final payments = [
        {'amount': null},
        {'amount': 5000},
      ];
      final totalPaid = payments.fold<double>(
        0,
        (sum, p) => sum + ((p['amount'] as num?)?.toDouble() ?? 0),
      );

      expect(totalPaid, 5000.0);
    });
  });

  group('Invoice - Date Parsing', () {
    test('parses valid ISO date', () {
      const dateStr = '2024-06-15';
      final date = DateTime.tryParse(dateStr);

      expect(date, isNotNull);
      expect(date!.year, 2024);
      expect(date.month, 6);
      expect(date.day, 15);
    });

    test('returns null for invalid date', () {
      const dateStr = 'invalid-date';
      final date = DateTime.tryParse(dateStr);

      expect(date, isNull);
    });

    test('returns null for empty date', () {
      const dateStr = '';
      DateTime? date;
      if (dateStr.isNotEmpty) {
        try {
          date = DateTime.parse(dateStr);
        } catch (_) {}
      }

      expect(date, isNull);
    });
  });

  group('Invoice - Data Extraction', () {
    test('extracts vendor with fallback', () {
      final invoice = {'vendor': 'Acme Corp'};
      expect(invoice['vendor']?.toString() ?? '', 'Acme Corp');

      final empty = <String, dynamic>{};
      expect(empty['vendor']?.toString() ?? '', '');
    });

    test('extracts nested project name', () {
      final invoice = {
        'projects': {'name': 'Site Alpha'}
      };
      expect(invoice['projects']?['name']?.toString() ?? '', 'Site Alpha');

      final noProject = <String, dynamic>{};
      expect(noProject['projects']?['name']?.toString() ?? '', '');
    });

    test('extracts nested user name', () {
      final invoice = {
        'users': {'full_name': 'John Doe'}
      };
      expect(invoice['users']?['full_name']?.toString() ?? '', 'John Doe');

      final noUser = <String, dynamic>{};
      expect(noUser['users']?['full_name']?.toString() ?? '', '');
    });

    test('extracts status badge text', () {
      const status = 'in_progress';
      expect(status.toUpperCase().replaceAll('_', ' '), 'IN PROGRESS');
    });
  });
}
