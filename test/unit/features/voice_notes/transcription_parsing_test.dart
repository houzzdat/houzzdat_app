import 'package:flutter_test/flutter_test.dart';

/// Tests for transcription parsing logic extracted from TranscriptionDisplay.
/// The parsing method `_parseTranscription` is private, so we test it via
/// a standalone function that mirrors the same logic.
///
/// This ensures the 4-strategy parsing engine works correctly.

/// Mirrors TranscriptionDisplay._parseTranscription
Map<String, String> parseTranscription(String? transcription) {
  if (transcription == null || transcription.isEmpty) {
    return {'original': '', 'translated': '', 'language': ''};
  }

  // STRATEGY 1: Try standard format [Language] text \n\n [English] translation
  final languagePattern = RegExp(
    r'\[(.*?)\]\s*(.*?)(?:\n\n\[English\]\s*(.*))?$',
    dotAll: true,
  );
  final match = languagePattern.firstMatch(transcription);

  if (match != null) {
    final language = match.group(1) ?? '';
    final original = match.group(2) ?? '';
    final translated = match.group(3) ?? '';

    return {
      'language': language,
      'original': original.trim(),
      'translated': translated.trim(),
    };
  }

  // STRATEGY 2: Check for two distinct paragraphs
  final parts = transcription.split('\n\n');
  if (parts.length >= 2) {
    return {
      'language': 'Unknown',
      'original': parts[0].trim(),
      'translated': parts.sublist(1).join('\n\n').trim(),
    };
  }

  // STRATEGY 3: Check for single newline separation
  final singleNewlineParts = transcription.split('\n');
  if (singleNewlineParts.length >= 2) {
    return {
      'language': 'Unknown',
      'original': singleNewlineParts[0].trim(),
      'translated': singleNewlineParts.sublist(1).join('\n').trim(),
    };
  }

  // STRATEGY 4: Single language transcript (likely English)
  final looksLikeEnglish = transcription.toLowerCase().contains(RegExp(
      r'\b(the|is|are|was|were|have|has|had|will|would|can|could|should|this|that)\b'));

  return {
    'language': looksLikeEnglish ? 'English' : 'Unknown',
    'original': transcription.trim(),
    'translated': '',
  };
}

void main() {
  group('parseTranscription - Strategy 1: Standard [Language] format', () {
    test('parses Hindi transcription with English translation', () {
      final result = parseTranscription(
          '[Hindi] यह एक परीक्षण है\n\n[English] This is a test');

      expect(result['language'], 'Hindi');
      expect(result['original'], 'यह एक परीक्षण है');
      expect(result['translated'], 'This is a test');
    });

    test('parses Spanish transcription with English translation', () {
      final result = parseTranscription(
          '[Spanish] Esta es una prueba\n\n[English] This is a test');

      expect(result['language'], 'Spanish');
      expect(result['original'], 'Esta es una prueba');
      expect(result['translated'], 'This is a test');
    });

    test('parses transcription with [English] tag only', () {
      final result = parseTranscription('[English] This is just English text');

      expect(result['language'], 'English');
      expect(result['original'], 'This is just English text');
    });

    test('handles multi-line native text with translation', () {
      final result = parseTranscription(
          '[Telugu] మొదటి వరుస\nరెండవ వరుస\n\n[English] First line\nSecond line');

      expect(result['language'], 'Telugu');
      expect(result['original'], contains('మొదటి వరుస'));
      expect(result['translated'], contains('First line'));
    });
  });

  group('parseTranscription - Strategy 2: Paragraph separation', () {
    test('splits on double newline', () {
      final result = parseTranscription(
          'これはテストです\n\nThis is a test');

      expect(result['language'], 'Unknown');
      expect(result['original'], 'これはテストです');
      expect(result['translated'], 'This is a test');
    });

    test('handles multiple paragraphs', () {
      final result = parseTranscription(
          'Original text\n\nTranslated part 1\n\nTranslated part 2');

      expect(result['original'], 'Original text');
      expect(result['translated'], 'Translated part 1\n\nTranslated part 2');
    });
  });

  group('parseTranscription - Strategy 3: Single newline separation', () {
    test('splits on single newline', () {
      final result = parseTranscription('Original line\nTranslated line');

      expect(result['language'], 'Unknown');
      expect(result['original'], 'Original line');
      expect(result['translated'], 'Translated line');
    });

    test('handles multiple lines', () {
      final result = parseTranscription('Line 1\nLine 2\nLine 3');

      expect(result['original'], 'Line 1');
      expect(result['translated'], 'Line 2\nLine 3');
    });
  });

  group('parseTranscription - Strategy 4: Single language detection', () {
    test('detects English text', () {
      final result = parseTranscription(
          'The construction work has been completed successfully');

      expect(result['language'], 'English');
      expect(result['original'],
          'The construction work has been completed successfully');
      expect(result['translated'], '');
    });

    test('marks non-English text as Unknown', () {
      final result = parseTranscription('これはテストです');

      expect(result['language'], 'Unknown');
      expect(result['original'], 'これはテストです');
      expect(result['translated'], '');
    });

    test('detects English via common words', () {
      final result = parseTranscription('This is a test message');
      expect(result['language'], 'English');
    });

    test('detects English via "would"', () {
      final result = parseTranscription('I would like to report');
      expect(result['language'], 'English');
    });

    test('detects English via "should"', () {
      final result = parseTranscription('We should fix the issue');
      expect(result['language'], 'English');
    });
  });

  group('parseTranscription - Edge cases', () {
    test('returns empty map for null input', () {
      final result = parseTranscription(null);

      expect(result['original'], '');
      expect(result['translated'], '');
      expect(result['language'], '');
    });

    test('returns empty map for empty string', () {
      final result = parseTranscription('');

      expect(result['original'], '');
      expect(result['translated'], '');
      expect(result['language'], '');
    });

    test('trims whitespace from results', () {
      final result = parseTranscription('  Some text with spaces  ');

      expect(result['original'], 'Some text with spaces');
    });

    test('handles very long transcription', () {
      final longText = 'This is a long test. ' * 100;
      final result = parseTranscription(longText);

      expect(result['language'], 'English');
      expect(result['original'], isNotEmpty);
    });
  });
}
