import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/voice_notes/widgets/editable_transcription_box.dart';

/// Component for displaying and managing transcriptions with ONE-TIME edit limit
class TranscriptionDisplay extends StatefulWidget {
  final String noteId;
  final String? transcription;
  final String status;
  final bool? isEdited;

  const TranscriptionDisplay({
    super.key,
    required this.noteId,
    required this.transcription,
    required this.status,
    this.isEdited,
  });

  @override
  State<TranscriptionDisplay> createState() => _TranscriptionDisplayState();
}

class _TranscriptionDisplayState extends State<TranscriptionDisplay> {
  final _supabase = Supabase.instance.client;
  bool _isSaving = false;
  
  Map<String, String> _parsedTranscription = {};

  @override
  void initState() {
    super.initState();
    _parsedTranscription = _parseTranscription(widget.transcription);
  }

  @override
  void didUpdateWidget(TranscriptionDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.transcription != widget.transcription) {
      _parsedTranscription = _parseTranscription(widget.transcription);
    }
  }

  Map<String, String> _parseTranscription(String? transcription) {
    if (transcription == null || transcription.isEmpty) {
      return {'original': '', 'translated': '', 'language': ''};
    }

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

    return {
      'language': 'English',
      'original': transcription,
      'translated': '',
    };
  }

  Widget _buildLanguageBadge(String language) {
    if (language.isEmpty || language.toLowerCase() == 'english') {
      return const SizedBox.shrink();
    }

    final flagEmojis = {
      'Spanish': '🇪🇸', 'French': '🇫🇷', 'German': '🇩🇪',
      'Italian': '🇮🇹', 'Portuguese': '🇵🇹', 'Russian': '🇷🇺',
      'Japanese': '🇯🇵', 'Korean': '🇰🇷', 'Chinese': '🇨🇳',
      'Arabic': '🇸🇦', 'Hindi': '🇮🇳', 'Telugu': '🇮🇳',
      'Tamil': '🇮🇳', 'Marathi': '🇮🇳', 'Bengali': '🇮🇳',
      'Urdu': '🇵🇰', 'Kannada': '🇮🇳', 'Malayalam': '🇮🇳',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingM,
        vertical: AppTheme.spacingS,
      ),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            flagEmojis[language] ?? '🌍',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            language.toUpperCase(),
            style: AppTheme.caption.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.warningOrange,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSave(String originalText, String englishText) async {
    // CRITICAL: Check if already edited
    if (widget.isEdited == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ This transcription has already been edited. Only one edit is allowed.'),
          backgroundColor: AppTheme.warningOrange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final language = _parsedTranscription['language'] ?? 'English';
      
      // Reconstruct the transcription format
      String newTranscription;
      if (language.toLowerCase() == 'english') {
        newTranscription = englishText;
      } else {
        newTranscription = '[$language] $originalText\n\n[English] $englishText';
      }

      await _supabase
          .from('voice_notes')
          .update({
            'transcription': newTranscription,
            'is_edited': true, // Mark as edited - prevents future edits
          })
          .eq('id', widget.noteId);

      if (mounted) {
        setState(() => _isSaving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Transcription updated! (No further edits allowed)'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasTranscription = widget.transcription != null && 
                             widget.transcription!.isNotEmpty;

    if (!hasTranscription) {
      if (widget.status == 'processing') {
        return Padding(
          padding: const EdgeInsets.only(top: AppTheme.spacingM),
          child: Row(
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppTheme.spacingS),
              Text(
                'Processing transcription...',
                style: AppTheme.bodySmall.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final language = _parsedTranscription['language']!;
    final original = _parsedTranscription['original']!;
    final translated = _parsedTranscription['translated']!;
    final isEnglishOnly = language.toLowerCase() == 'english';
    
    // CRITICAL: Check if already edited
    final alreadyEdited = widget.isEdited == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spacingM),
        
        _buildLanguageBadge(language),

        // Show warning if already edited
        if (alreadyEdited) ...[
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
              border: Border.all(color: AppTheme.warningOrange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock, size: 16, color: AppTheme.warningOrange),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    'This transcription has been edited. No further changes allowed.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.warningOrange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Original Language (if not English)
        if (!isEnglishOnly && original.isNotEmpty) ...[
          EditableTranscriptionBox(
            title: language.toUpperCase(),
            initialText: original,
            isNativeLanguage: true,
            isSaving: _isSaving,
            isLocked: alreadyEdited, // Pass locked state
            onSave: (newOriginal) {
              _handleSave(newOriginal, translated);
            },
          ),
          const SizedBox(height: AppTheme.spacingM),
        ],

        // English Translation
        if (translated.isNotEmpty || isEnglishOnly) ...[
          EditableTranscriptionBox(
            title: 'ENGLISH',
            initialText: isEnglishOnly ? original : translated,
            isNativeLanguage: false,
            isSaving: _isSaving,
            isLocked: alreadyEdited, // Pass locked state
            onSave: (newEnglish) {
              _handleSave(original, newEnglish);
            },
          ),
        ],
      ],
    );
  }
}