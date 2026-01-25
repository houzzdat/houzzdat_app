import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Reusable component for displaying and editing transcription text
/// Now supports locked state to prevent edits
class EditableTranscriptionBox extends StatefulWidget {
  final String title;
  final String initialText;
  final bool isNativeLanguage;
  final bool isSaving;
  final bool isLocked; // NEW: Prevents editing if true
  final Function(String) onSave;

  const EditableTranscriptionBox({
    super.key,
    required this.title,
    required this.initialText,
    required this.isNativeLanguage,
    required this.isSaving,
    this.isLocked = false, // NEW: Default to not locked
    required this.onSave,
  });

  @override
  State<EditableTranscriptionBox> createState() => _EditableTranscriptionBoxState();
}

class _EditableTranscriptionBoxState extends State<EditableTranscriptionBox> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void didUpdateWidget(EditableTranscriptionBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialText != widget.initialText && !_isEditing) {
      _controller.text = widget.initialText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleEdit() {
    // CRITICAL: Don't allow editing if locked
    if (widget.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ This transcription has already been edited. No further changes allowed.'),
          backgroundColor: AppTheme.warningOrange,
        ),
      );
      return;
    }
    setState(() => _isEditing = true);
  }

  void _handleCancel() {
    setState(() {
      _isEditing = false;
      _controller.text = widget.initialText;
    });
  }

  void _handleSave() {
    widget.onSave(_controller.text.trim());
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      decoration: BoxDecoration(
        color: widget.isNativeLanguage
            ? Colors.white
            : AppTheme.infoBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppTheme.radiusM),
        border: Border.all(
          color: widget.isLocked
              ? AppTheme.warningOrange.withOpacity(0.3) // Show locked state
              : widget.isNativeLanguage
                  ? AppTheme.textSecondary.withOpacity(0.2)
                  : AppTheme.infoBlue.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and edit button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (!widget.isNativeLanguage) ...[
                    Icon(Icons.translate, size: 14, color: AppTheme.infoBlue),
                    const SizedBox(width: AppTheme.spacingS),
                  ],
                  if (widget.isLocked) ...[
                    const Icon(Icons.lock, size: 14, color: AppTheme.warningOrange),
                    const SizedBox(width: AppTheme.spacingS),
                  ],
                  Text(
                    widget.title,
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.bold,
                      color: widget.isLocked
                          ? AppTheme.warningOrange
                          : widget.isNativeLanguage 
                              ? AppTheme.textSecondary 
                              : AppTheme.infoBlue,
                    ),
                  ),
                ],
              ),
              if (!_isEditing)
                IconButton(
                  icon: Icon(
                    widget.isLocked ? Icons.lock : Icons.edit,
                    size: 16,
                  ),
                  onPressed: _handleEdit,
                  tooltip: widget.isLocked ? 'Editing locked' : 'Edit transcription',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: widget.isLocked 
                      ? AppTheme.warningOrange 
                      : AppTheme.primaryIndigo,
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingS),
          
          // Content - either text or editable field
          if (_isEditing)
            Column(
              children: [
                TextField(
                  controller: _controller,
                  maxLines: 5,
                  style: AppTheme.bodyMedium.copyWith(height: 1.5),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                    ),
                    contentPadding: const EdgeInsets.all(AppTheme.spacingM),
                    hintText: 'Edit transcription...',
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: AppTheme.spacingS),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: widget.isSaving ? null : _handleCancel,
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AppTheme.spacingS),
                    ElevatedButton.icon(
                      onPressed: widget.isSaving ? null : _handleSave,
                      icon: widget.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save, size: 16),
                      label: Text(widget.isSaving ? 'Saving...' : 'Save (One-Time Only)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            )
          else
            Text(
              _controller.text.isEmpty 
                  ? 'No transcription available' 
                  : _controller.text,
              style: AppTheme.bodyMedium.copyWith(
                height: 1.5,
                fontStyle: widget.isNativeLanguage ? FontStyle.italic : FontStyle.normal,
                color: _controller.text.isEmpty 
                    ? AppTheme.textSecondary 
                    : AppTheme.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}