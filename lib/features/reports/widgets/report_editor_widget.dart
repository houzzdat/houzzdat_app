import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Editable report widget with preview/edit toggle and auto-save.
class ReportEditorWidget extends StatefulWidget {
  final String reportId;
  final String initialContent;
  final String reportType; // 'manager' or 'owner'
  final bool isEditable;
  final ValueChanged<String>? onContentChanged;

  const ReportEditorWidget({
    super.key,
    required this.reportId,
    required this.initialContent,
    required this.reportType,
    this.isEditable = true,
    this.onContentChanged,
  });

  @override
  State<ReportEditorWidget> createState() => _ReportEditorWidgetState();
}

class _ReportEditorWidgetState extends State<ReportEditorWidget> {
  final _supabase = Supabase.instance.client;
  late TextEditingController _controller;
  bool _isEditMode = false;
  bool _isSaving = false;
  String _saveStatus = '';
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
  }

  @override
  void didUpdateWidget(covariant ReportEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialContent != widget.initialContent) {
      _controller.text = widget.initialContent;
    }
    if (oldWidget.isEditable != widget.isEditable && !widget.isEditable) {
      _isEditMode = false;
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    widget.onContentChanged?.call(text);
    _autoSaveTimer?.cancel();
    setState(() => _saveStatus = 'Unsaved changes');
    _autoSaveTimer = Timer(const Duration(milliseconds: 1500), () {
      _saveToDatabase(text);
    });
  }

  Future<void> _saveToDatabase(String content) async {
    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _saveStatus = 'Saving...';
    });

    try {
      final field = widget.reportType == 'manager'
          ? 'manager_report_content'
          : 'owner_report_content';

      await _supabase.from('reports').update({
        field: content,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.reportId);

      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = 'Saved';
        });
        // Clear status after 3 seconds
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted && _saveStatus == 'Saved') {
            setState(() => _saveStatus = '');
          }
        });
      }
    } catch (e) {
      debugPrint('Error saving report: $e');
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveStatus = 'Save failed';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingXS,
          ),
          color: Colors.white,
          child: Row(
            children: [
              // Edit/Preview toggle
              if (widget.isEditable)
                GestureDetector(
                  onTap: () => setState(() => _isEditMode = !_isEditMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isEditMode
                          ? AppTheme.primaryIndigo.withValues(alpha: 0.1)
                          : AppTheme.backgroundGrey,
                      borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      border: Border.all(
                        color: _isEditMode
                            ? AppTheme.primaryIndigo.withValues(alpha: 0.3)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isEditMode ? Icons.preview : Icons.edit,
                          size: 16,
                          color: _isEditMode
                              ? AppTheme.primaryIndigo
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isEditMode ? 'Preview' : 'Edit',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _isEditMode
                                ? AppTheme.primaryIndigo
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (!widget.isEditable)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusS),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: AppTheme.textSecondary),
                      SizedBox(width: 4),
                      Text(
                        'Locked',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              // Save status
              if (_saveStatus.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    if (!_isSaving && _saveStatus == 'Saved')
                      const Icon(Icons.check_circle, size: 14, color: AppTheme.successGreen),
                    if (!_isSaving && _saveStatus == 'Save failed')
                      const Icon(Icons.error_outline, size: 14, color: AppTheme.errorRed),
                    const SizedBox(width: 4),
                    Text(
                      _saveStatus,
                      style: TextStyle(
                        fontSize: 11,
                        color: _saveStatus == 'Save failed'
                            ? AppTheme.errorRed
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0)),

        // Content area
        Expanded(
          child: _isEditMode && widget.isEditable
              ? _buildEditMode()
              : _buildPreviewMode(),
        ),
      ],
    );
  }

  Widget _buildPreviewMode() {
    final content = _controller.text;
    if (content.isEmpty) {
      return const Center(
        child: Text(
          'No content yet',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    return Markdown(
      data: content,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      styleSheet: MarkdownStyleSheet(
        h1: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryIndigo,
        ),
        h2: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryIndigo,
        ),
        h3: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
        p: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textPrimary),
        listBullet: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        strong: const TextStyle(fontWeight: FontWeight.w700),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
              width: 3,
            ),
          ),
        ),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Colors.grey.shade300, width: 1),
          ),
        ),
      ),
    );
  }

  Widget _buildEditMode() {
    return Container(
      color: const Color(0xFFFAFAFA),
      child: TextField(
        controller: _controller,
        onChanged: _onTextChanged,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: const TextStyle(
          fontSize: 13,
          fontFamily: 'monospace',
          height: 1.6,
          color: AppTheme.textPrimary,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(AppTheme.spacingM),
          hintText: 'Write your report in Markdown format...',
          hintStyle: TextStyle(color: AppTheme.textSecondary),
        ),
      ),
    );
  }
}
