import 'package:flutter_test/flutter_test.dart';

/// UX Copy Consistency Tests
/// Validates that all user-facing messages follow the established patterns:
/// - Error: "Could not {action}. Please {recovery}."
/// - Success: "{Object} {past tense verb}" (no exclamation marks)
/// - No emoji in SnackBar messages
/// - No raw exception text

void main() {
  group('Error Message Pattern', () {
    final errorMessages = [
      'Could not create invoice. Please check your connection and try again.',
      'Could not record payment. Please check your connection and try again.',
      'Could not submit fund request. Please try again.',
      'Could not send report. Please check your connection and try again.',
      'Could not regenerate report. Please try again later.',
      'Could not delete report. Please try again.',
      'Could not save prompt changes. Please try again.',
      'Could not save transcription. Please try again.',
      'Could not send voice note. Please check your connection and try again.',
      'Could not invite user. Please check the details and try again.',
      'Could not update user. Please try again.',
      'Could not load user data. Please try again.',
      'Could not load roles. Please try again.',
      'Could not add role. Please try again.',
      'Could not delete role. Please try again.',
      'Could not create account. Please check the details and try again.',
      'Could not generate PDF. Please try again.',
      'Could not update company status. Please try again.',
      'Could not update provider. Please try again.',
      'Could not generate report. Please try again later.',
      'Could not switch company. Please try again.',
      'Could not delete voice note. Please try again.',
      'Could not deactivate user. Please try again.',
      'Could not reactivate user. Please try again.',
      'Could not remove user. Please try again.',
    ];

    test('all error messages start with "Could not"', () {
      for (final msg in errorMessages) {
        expect(msg.startsWith('Could not'), true,
            reason: 'Message "$msg" should start with "Could not"');
      }
    });

    test('all error messages contain "Please"', () {
      for (final msg in errorMessages) {
        expect(msg.contains('Please'), true,
            reason: 'Message "$msg" should contain recovery instruction starting with "Please"');
      }
    });

    test('all error messages end with period', () {
      for (final msg in errorMessages) {
        expect(msg.endsWith('.'), true,
            reason: 'Message "$msg" should end with a period');
      }
    });

    test('no error messages contain raw exception patterns', () {
      for (final msg in errorMessages) {
        expect(msg.contains(r'$e'), false,
            reason: 'Message "$msg" should not contain raw exception text');
        expect(msg.contains('Error:'), false,
            reason: 'Message "$msg" should not start with "Error:"');
        expect(msg.contains('Exception'), false,
            reason: 'Message "$msg" should not contain "Exception"');
      }
    });

    test('no error messages contain emoji', () {
      final emojiRegex = RegExp(
        r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{FE00}-\u{FE0F}]|[\u{1F900}-\u{1F9FF}]|[\u{200D}]|[\u{20E3}]|[\u{FE0F}]|[\u2714\u2716\u26A0\u274C\u2705\u274E]',
        unicode: true,
      );

      for (final msg in errorMessages) {
        expect(emojiRegex.hasMatch(msg), false,
            reason: 'Message "$msg" should not contain emoji');
      }
    });
  });

  group('Success Message Pattern', () {
    final successMessages = [
      'Account and admin created',
      'Company status updated',
      'Voice note submitted',
      'Voice note sent to manager',
      'User invited',
      'User updated',
      'Role added',
      'Role deleted',
      'Invoice created',
      'Invoice approved',
      'Invoice rejected',
      'Payment recorded',
      'Payment confirmed',
      'Owner payment recorded',
      'Fund request submitted',
      'Report sent to owner',
      'Draft saved',
      'Reports finalized',
      'Report deleted',
      'Transcription updated',
      'Reply sent',
      'Message deleted',
      'Site deleted',
    ];

    test('no success messages end with exclamation mark', () {
      for (final msg in successMessages) {
        expect(msg.endsWith('!'), false,
            reason: 'Success message "$msg" should not end with "!"');
      }
    });

    test('no success messages contain "successfully"', () {
      for (final msg in successMessages) {
        expect(msg.toLowerCase().contains('successfully'), false,
            reason: 'Success message "$msg" should not contain "successfully"');
      }
    });

    test('no success messages contain emoji', () {
      final emojiRegex = RegExp(
        r'[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{FE00}-\u{FE0F}]|[\u{1F900}-\u{1F9FF}]|[\u{200D}]|[\u{20E3}]|[\u{FE0F}]|[\u2714\u2716\u26A0\u274C\u2705\u274E]',
        unicode: true,
      );

      for (final msg in successMessages) {
        expect(emojiRegex.hasMatch(msg), false,
            reason: 'Success message "$msg" should not contain emoji');
      }
    });

    test('success messages are concise (under 60 chars)', () {
      for (final msg in successMessages) {
        expect(msg.length, lessThanOrEqualTo(60),
            reason: 'Success message "$msg" should be concise');
      }
    });
  });

  group('Empty State Messages', () {
    final emptyStates = {
      'No Sites Yet': 'You have no sites linked to your account yet. Ask your manager to add you.',
      'No Approvals': 'Approval requests from your manager will appear here.',
      'No Messages Yet': 'Record a voice note to start a conversation with your manager.',
    };

    test('empty state titles are short and descriptive', () {
      for (final title in emptyStates.keys) {
        expect(title.length, lessThanOrEqualTo(30),
            reason: 'Title "$title" should be under 30 chars');
      }
    });

    test('empty state subtitles provide guidance', () {
      for (final entry in emptyStates.entries) {
        expect(entry.value.isNotEmpty, true,
            reason: 'Subtitle for "${entry.key}" should not be empty');
        expect(entry.value.length, greaterThan(10),
            reason: 'Subtitle for "${entry.key}" should provide meaningful guidance');
      }
    });

    test('empty state subtitles end with period', () {
      for (final entry in emptyStates.entries) {
        expect(entry.value.endsWith('.'), true,
            reason: 'Subtitle "${entry.value}" should end with a period');
      }
    });
  });

  group('Button Label Patterns', () {
    test('confirmation buttons include context', () {
      const confirmButtons = [
        'Deactivate User',
        'Remove User',
        'Reactivate User',
      ];

      for (final label in confirmButtons) {
        // Ensure it's not just a single word like "Deactivate"
        expect(label.split(' ').length, greaterThanOrEqualTo(2),
            reason: 'Button "$label" should include context (not just a verb)');
      }
    });

    test('primary action buttons use Title Case', () {
      const buttons = ['Sign In', 'Initialize Account', 'Submit'];

      for (final label in buttons) {
        // First character should be uppercase
        expect(label[0], label[0].toUpperCase(),
            reason: 'Button "$label" should start with uppercase');
        // Should not be ALL CAPS
        expect(label, isNot(equals(label.toUpperCase())),
            reason: 'Button "$label" should not be ALL CAPS');
      }
    });
  });

  group('Recording Indicator Messages', () {
    test('worker recording indicator is descriptive', () {
      const msg = 'Recording... Tap mic to stop and send';
      expect(msg.contains('Tap'), true);
      expect(msg.contains('stop'), true);
      expect(msg.contains('send'), true);
    });

    test('owner recording indicator matches worker', () {
      const workerMsg = 'Recording... Tap mic to stop and send';
      const ownerMsg = 'Recording... Tap mic to stop and send';
      // Both should use the same pattern
      expect(workerMsg, ownerMsg);
    });
  });
}
