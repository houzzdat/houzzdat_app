import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

/// Component for displaying and managing transcriptions with ONE-TIME edit limit
/// FIXED: Compatible with existing EditableTranscriptionBox interface
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

  /// ENHANCED: Multi-strategy transcript parsing with fallbacks
  Map<String, String> _parseTranscription(String? transcription) {
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
      r'\b(the|is|are|was|were|have|has|had|will|would|can|could|should|this|that)\b'
    ));

    return {
      'language': looksLikeEnglish ? 'English' : 'Unknown',
      'original': transcription.trim(),
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
      'Gujarati': '🇮🇳', 'Punjabi': '🇮🇳', 'Unknown': '🌐',
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

  Future<void> _handleSave(String text, bool isNative) async {
    if (widget.isEdited == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ This transcription has already been edited. Only one edit is allowed.'),
            backgroundColor: AppTheme.warningOrange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final language = _parsedTranscription['language'] ?? 'English';
      final original = _parsedTranscription['original'] ?? '';
      final translated = _parsedTranscription['translated'] ?? '';

      // Update the appropriate text
      final newOriginal = isNative ? text : original;
      final newTranslated = isNative ? translated : text;

      // Reconstruct transcription
      String newTranscription;
      if (language.toLowerCase() == 'english') {
        newTranscription = text;
      } else {
        newTranscription = '[$language] $newOriginal\n\n[English] $newTranslated';
      }

      await _supabase.from('voice_notes').update({
        'transcription': newTranscription,
        'transcript_final': newTranslated.isNotEmpty ? newTranslated : text,
        'is_edited': true,
        'last_edited_by': _supabase.auth.currentUser?.id,
        'last_edited_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.noteId);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Transcription updated!'),
            backgroundColor: AppTheme.successGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  /// Build simple editable text box (inline, no separate widget)
  Widget _buildEditableBox({
    required String label,
    required String text,
    required bool isNative,
    required bool isLocked,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: isNative
            ? Colors.white
            : AppTheme.infoBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: isLocked
              ? AppTheme.warningOrange.withOpacity(0.3)
              : isNative
                  ? AppTheme.textSecondary.withOpacity(0.2)
                  : AppTheme.infoBlue.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (!isNative) ...[
                    const Icon(Icons.translate, size: 14, color: AppTheme.infoBlue),
                    const SizedBox(width: AppTheme.spacingS),
                  ],
                  if (isLocked) ...[
                    const Icon(Icons.lock, size: 14, color: AppTheme.warningOrange),
                    const SizedBox(width: AppTheme.spacingS),
                  ],
                  Text(
                    label,
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isLocked
                          ? AppTheme.warningOrange
                          : isNative
                              ? AppTheme.textSecondary
                              : AppTheme.infoBlue,
                    ),
                  ),
                ],
              ),
              if (!isLocked)
                IconButton(
                  icon: const Icon(Icons.edit, size: 16),
                  onPressed: () => _showEditDialog(text, isNative, label),
                  tooltip: 'Edit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppTheme.primaryIndigo,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          Text(
            text.isEmpty ? 'No transcription available' : text,
            style: AppTheme.bodyMedium.copyWith(
              height: 1.5,
              fontStyle: isNative ? FontStyle.italic : FontStyle.normal,
              color: text.isEmpty ? AppTheme.textSecondary : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(String currentText, bool isNative, String label) {
    final controller = TextEditingController(text: currentText);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $label'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter transcription...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleSave(controller.text.trim(), isNative);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
            ),
            child: Text(_isSaving ? 'Saving...' : 'Save'),
          ),
        ],
      ),
    );
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
    final alreadyEdited = widget.isEdited == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppTheme.spacingM),
        
        _buildLanguageBadge(language),

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

        if (!isEnglishOnly && original.isNotEmpty) ...[
          _buildEditableBox(
            label: language.toUpperCase(),
            text: original,
            isNative: true,
            isLocked: alreadyEdited,
          ),
          const SizedBox(height: AppTheme.spacingM),
        ],

        if (translated.isNotEmpty || isEnglishOnly) ...[
          _buildEditableBox(
            label: 'ENGLISH',
            text: isEnglishOnly ? original : translated,
            isNative: false,
            isLocked: alreadyEdited,
          ),
        ],
      ],
    );
  }
}