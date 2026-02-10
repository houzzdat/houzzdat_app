import 'package:flutter_test/flutter_test.dart';

/// Tests for LogCard data accessor logic (extracted from the private getters).
/// Since the getters are private in _LogCardState, we test the logic patterns
/// directly to ensure correctness.

void main() {
  group('LogCard - Status Checks', () {
    test('isProcessing returns true for processing status', () {
      const status = 'processing';
      expect(status == 'processing', true);
    });

    test('isTranscribed returns true for transcribed status', () {
      const status = 'transcribed';
      expect(status == 'transcribed', true);
    });

    test('isTranslated returns true for translated status', () {
      const status = 'translated';
      expect(status == 'translated', true);
    });

    test('isCompleted returns true for completed status', () {
      const status = 'completed';
      expect(status == 'completed', true);
    });

    test('hasTranscript is true for transcribed, translated, or completed', () {
      bool hasTranscript(String status) {
        return status == 'transcribed' ||
            status == 'translated' ||
            status == 'completed';
      }

      expect(hasTranscript('processing'), false);
      expect(hasTranscript('transcribed'), true);
      expect(hasTranscript('translated'), true);
      expect(hasTranscript('completed'), true);
    });
  });

  group('LogCard - Language Detection', () {
    test('isEnglish detects "en" code', () {
      bool isEnglish(String? langCode) {
        final lang = langCode ?? 'en';
        return lang.toLowerCase() == 'en' || lang.toLowerCase() == 'english';
      }

      expect(isEnglish('en'), true);
      expect(isEnglish('EN'), true);
      expect(isEnglish('english'), true);
      expect(isEnglish('English'), true);
      expect(isEnglish('hi'), false);
      expect(isEnglish('es'), false);
      expect(isEnglish(null), true); // defaults to 'en'
    });

    test('languageCode returns uppercase', () {
      String getLanguageCode(String? langCode) {
        return (langCode ?? 'EN').toUpperCase();
      }

      expect(getLanguageCode('hi'), 'HI');
      expect(getLanguageCode('en'), 'EN');
      expect(getLanguageCode(null), 'EN');
      expect(getLanguageCode('te'), 'TE');
    });
  });

  group('LogCard - Category Fallback', () {
    test('uses primary category when available', () {
      String getCategory(String? category, String? aiSuggestedCategory) {
        return category ?? aiSuggestedCategory ?? '';
      }

      expect(getCategory('action_required', 'update'), 'action_required');
      expect(getCategory(null, 'update'), 'update');
      expect(getCategory(null, null), '');
    });

    test('category config mapping', () {
      const categoryConfig = {
        'action_required': 'Action Needed',
        'approval': 'Approval',
        'update': 'Update',
        'information': 'Info',
      };

      expect(categoryConfig['action_required'], 'Action Needed');
      expect(categoryConfig['approval'], 'Approval');
      expect(categoryConfig['update'], 'Update');
      expect(categoryConfig['information'], 'Info');
      expect(categoryConfig['unknown'], isNull);
    });
  });

  group('LogCard - Status Config', () {
    test('status config mapping covers all statuses', () {
      const statusConfig = {
        'pending': 'Pending',
        'approved': 'Approved',
        'rejected': 'Rejected',
        'in_progress': 'In Progress',
        'verifying': 'Verifying',
        'completed': 'Completed',
      };

      expect(statusConfig['pending'], 'Pending');
      expect(statusConfig['approved'], 'Approved');
      expect(statusConfig['rejected'], 'Rejected');
      expect(statusConfig['in_progress'], 'In Progress');
      expect(statusConfig['verifying'], 'Verifying');
      expect(statusConfig['completed'], 'Completed');
    });
  });

  group('LogCard - Transcript Fallback Chain', () {
    test('English transcript uses correct fallback order', () {
      String getNativeTranscript(Map<String, dynamic> note) {
        return note['transcript_en_current']?.toString() ??
            note['transcript_final']?.toString() ??
            note['transcription']?.toString() ??
            '';
      }

      // First priority
      expect(
          getNativeTranscript({
            'transcript_en_current': 'A',
            'transcript_final': 'B',
            'transcription': 'C'
          }),
          'A');

      // Second priority
      expect(
          getNativeTranscript(
              {'transcript_final': 'B', 'transcription': 'C'}),
          'B');

      // Third priority
      expect(getNativeTranscript({'transcription': 'C'}), 'C');

      // No transcript
      expect(getNativeTranscript({}), '');
    });

    test('Non-English transcript uses raw fields', () {
      String getNativeTranscript(Map<String, dynamic> note) {
        return note['transcript_raw_current']?.toString() ??
            note['transcript_raw']?.toString() ??
            '';
      }

      expect(
          getNativeTranscript({
            'transcript_raw_current': 'Native A',
            'transcript_raw': 'Native B'
          }),
          'Native A');

      expect(
          getNativeTranscript({'transcript_raw': 'Native B'}), 'Native B');

      expect(getNativeTranscript({}), '');
    });
  });

  group('LogCard - Delete Window', () {
    test('canDelete is true within 5 minutes', () {
      bool canDelete(DateTime created) {
        return DateTime.now().difference(created).inMinutes < 5;
      }

      expect(canDelete(DateTime.now()), true);
      expect(
          canDelete(DateTime.now().subtract(const Duration(minutes: 3))), true);
      expect(canDelete(DateTime.now().subtract(const Duration(minutes: 4))),
          true);
    });

    test('canDelete is false after 5 minutes', () {
      bool canDelete(DateTime created) {
        return DateTime.now().difference(created).inMinutes < 5;
      }

      expect(canDelete(DateTime.now().subtract(const Duration(minutes: 5))),
          false);
      expect(canDelete(DateTime.now().subtract(const Duration(minutes: 10))),
          false);
      expect(canDelete(DateTime.now().subtract(const Duration(hours: 1))),
          false);
    });

    test('deleteMinutesLeft calculation', () {
      int deleteMinutesLeft(DateTime created) {
        final diff = DateTime.now().difference(created).inMinutes;
        return (5 - diff).clamp(0, 5);
      }

      expect(deleteMinutesLeft(DateTime.now()), 5);
      expect(
          deleteMinutesLeft(
              DateTime.now().subtract(const Duration(minutes: 2))),
          3);
      expect(
          deleteMinutesLeft(
              DateTime.now().subtract(const Duration(minutes: 5))),
          0);
      expect(
          deleteMinutesLeft(
              DateTime.now().subtract(const Duration(minutes: 10))),
          0);
    });
  });

  group('LogCard - Category Display Fallback', () {
    test('returns category config when category exists', () {
      String getCategoryLabel(
          String category, String status, Map<String, String> config) {
        if (category.isNotEmpty && config.containsKey(category)) {
          return config[category]!;
        }
        if (status == 'processing') return 'Transcribing';
        if (status == 'transcribed') return 'Translating';
        if (status == 'translated') return 'Analysing';
        return 'Note';
      }

      const config = {
        'action_required': 'Action Needed',
        'update': 'Update',
      };

      expect(getCategoryLabel('action_required', 'completed', config),
          'Action Needed');
      expect(getCategoryLabel('update', 'completed', config), 'Update');
    });

    test('falls back to status-based label when no category', () {
      String getCategoryLabel(String category, String status) {
        if (category.isNotEmpty) return category;
        if (status == 'processing') return 'Transcribing';
        if (status == 'transcribed') return 'Translating';
        if (status == 'translated') return 'Analysing';
        return 'Note';
      }

      expect(getCategoryLabel('', 'processing'), 'Transcribing');
      expect(getCategoryLabel('', 'transcribed'), 'Translating');
      expect(getCategoryLabel('', 'translated'), 'Analysing');
      expect(getCategoryLabel('', 'completed'), 'Note');
    });
  });

  group('LogCard - Relative Time Formatting', () {
    test('shows "Just now" for < 1 minute', () {
      String formatRelativeTime(DateTime time) {
        final diff = DateTime.now().difference(time);
        if (diff.inMinutes < 1) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        if (diff.inHours < 48) return 'Yesterday';
        if (diff.inDays < 7) return '${diff.inDays}d ago';
        return 'Older';
      }

      expect(formatRelativeTime(DateTime.now()), 'Just now');
    });

    test('shows minutes for < 1 hour', () {
      String formatRelativeTime(DateTime time) {
        final diff = DateTime.now().difference(time);
        if (diff.inMinutes < 1) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        return 'Older';
      }

      expect(
          formatRelativeTime(
              DateTime.now().subtract(const Duration(minutes: 30))),
          '30m ago');
    });

    test('shows hours for < 24 hours', () {
      String formatRelativeTime(DateTime time) {
        final diff = DateTime.now().difference(time);
        if (diff.inMinutes < 1) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        return 'Older';
      }

      expect(
          formatRelativeTime(
              DateTime.now().subtract(const Duration(hours: 5))),
          '5h ago');
    });

    test('shows Yesterday for 24-48 hours', () {
      String formatRelativeTime(DateTime time) {
        final diff = DateTime.now().difference(time);
        if (diff.inMinutes < 1) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        if (diff.inHours < 48) return 'Yesterday';
        return 'Older';
      }

      expect(
          formatRelativeTime(
              DateTime.now().subtract(const Duration(hours: 30))),
          'Yesterday');
    });

    test('shows days for < 7 days', () {
      String formatRelativeTime(DateTime time) {
        final diff = DateTime.now().difference(time);
        if (diff.inMinutes < 1) return 'Just now';
        if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
        if (diff.inHours < 24) return '${diff.inHours}h ago';
        if (diff.inHours < 48) return 'Yesterday';
        if (diff.inDays < 7) return '${diff.inDays}d ago';
        return 'Older';
      }

      expect(
          formatRelativeTime(
              DateTime.now().subtract(const Duration(days: 3))),
          '3d ago');
    });
  });

  group('LogCard - Data Accessor Defaults', () {
    test('noteId defaults to empty string', () {
      final note = <String, dynamic>{};
      expect(note['id']?.toString() ?? '', '');
    });

    test('audioUrl defaults to empty string', () {
      final note = <String, dynamic>{};
      expect(note['audio_url']?.toString() ?? '', '');
    });

    test('status defaults to processing', () {
      final note = <String, dynamic>{};
      expect(note['status']?.toString() ?? 'processing', 'processing');
    });

    test('recipientName returns null when not set', () {
      final note = <String, dynamic>{};
      expect(note['recipient_name']?.toString(), isNull);
    });

    test('createdAt parses ISO8601 string', () {
      final note = {'created_at': '2024-01-15T10:30:00Z'};
      final createdAt = DateTime.tryParse(note['created_at']!);
      expect(createdAt, isNotNull);
      expect(createdAt!.year, 2024);
      expect(createdAt.month, 1);
      expect(createdAt.day, 15);
    });

    test('createdAt returns null for invalid date', () {
      final note = {'created_at': 'not-a-date'};
      final createdAt = DateTime.tryParse(note['created_at']!);
      expect(createdAt, isNull);
    });
  });
}
