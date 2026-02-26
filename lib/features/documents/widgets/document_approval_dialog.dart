import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/documents/services/document_service.dart';
import 'package:houzzdat_app/models/models.dart';

enum ApprovalAction { approve, reject, requestChanges }

class DocumentApprovalDialog extends StatefulWidget {
  final Document document;

  const DocumentApprovalDialog({super.key, required this.document});

  static Future<bool?> show(BuildContext context, Document document) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DocumentApprovalDialog(document: document),
    );
  }

  @override
  State<DocumentApprovalDialog> createState() => _DocumentApprovalDialogState();
}

class _DocumentApprovalDialogState extends State<DocumentApprovalDialog> {
  final _commentController = TextEditingController();
  final _service = DocumentService();
  ApprovalAction? _selectedAction;
  bool _isProcessing = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  bool get _requiresComment =>
      _selectedAction == ApprovalAction.reject ||
      _selectedAction == ApprovalAction.requestChanges;

  Future<void> _submit() async {
    if (_selectedAction == null) return;
    if (_requiresComment && _commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add a comment explaining the decision')),
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      switch (_selectedAction!) {
        case ApprovalAction.approve:
          await _service.approveDocument(
            widget.document.id,
            comment: _commentController.text.trim().isEmpty
                ? null
                : _commentController.text.trim(),
          );
          break;
        case ApprovalAction.reject:
          await _service.rejectDocument(
            widget.document.id,
            _commentController.text.trim(),
          );
          break;
        case ApprovalAction.requestChanges:
          await _service.requestChanges(
            widget.document.id,
            _commentController.text.trim(),
          );
          break;
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.clipboardCheck, color: AppTheme.primaryIndigo, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Review Document',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.pop(context, false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              widget.document.name,
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            if (widget.document.versionNumber > 1)
              Text(
                'Version ${widget.document.versionNumber}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            const SizedBox(height: 20),

            // Action selection
            const Text('Your decision:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 10),
            _buildActionCard(
              action: ApprovalAction.approve,
              icon: LucideIcons.checkCircle,
              label: 'Approve',
              description: 'Document is accepted as-is',
              color: AppTheme.successGreen,
            ),
            const SizedBox(height: 8),
            _buildActionCard(
              action: ApprovalAction.requestChanges,
              icon: LucideIcons.edit,
              label: 'Request Changes',
              description: 'Ask manager to revise and resubmit',
              color: const Color(0xFF6A1B9A),
            ),
            const SizedBox(height: 8),
            _buildActionCard(
              action: ApprovalAction.reject,
              icon: LucideIcons.xCircle,
              label: 'Reject',
              description: 'Document is not accepted',
              color: AppTheme.errorRed,
            ),
            const SizedBox(height: 16),

            // Comment field
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: _requiresComment
                    ? 'Reason / Comment *'
                    : 'Comment (optional)',
                border: const OutlineInputBorder(),
                hintText: _selectedAction == ApprovalAction.approve
                    ? 'Any notes for the manager...'
                    : 'Explain what needs to change...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: (_selectedAction == null || _isProcessing) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAction != null
                      ? _actionColor(_selectedAction!)
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                        _selectedAction == null
                            ? 'Select a decision above'
                            : _actionLabel(_selectedAction!),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required ApprovalAction action,
    required IconData icon,
    required String label,
    required String description,
    required Color color,
  }) {
    final isSelected = _selectedAction == action;
    return GestureDetector(
      onTap: () => setState(() => _selectedAction = action),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(10),
          color: isSelected ? color.withValues(alpha: 0.06) : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? color : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: isSelected ? color : null,
                  )),
                  Text(description, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ],
              ),
            ),
            if (isSelected)
              Icon(LucideIcons.checkCircle, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Color _actionColor(ApprovalAction action) {
    switch (action) {
      case ApprovalAction.approve: return AppTheme.successGreen;
      case ApprovalAction.reject: return AppTheme.errorRed;
      case ApprovalAction.requestChanges: return const Color(0xFF6A1B9A);
    }
  }

  String _actionLabel(ApprovalAction action) {
    switch (action) {
      case ApprovalAction.approve: return 'Approve Document';
      case ApprovalAction.reject: return 'Reject Document';
      case ApprovalAction.requestChanges: return 'Request Changes';
    }
  }
}
