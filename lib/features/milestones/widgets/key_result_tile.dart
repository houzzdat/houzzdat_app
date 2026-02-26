import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/models/models.dart';

class KeyResultTile extends StatelessWidget {
  final KeyResult keyResult;
  final bool canEdit;
  final VoidCallback? onTap;
  final VoidCallback? onEditTap;
  final VoidCallback? onDeleteTap;

  const KeyResultTile({
    super.key,
    required this.keyResult,
    this.canEdit = false,
    this.onTap,
    this.onEditTap,
    this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress = keyResult.progressPercent / 100;
    final color = keyResult.completed
        ? AppTheme.successGreen
        : progress >= 0.7
            ? AppTheme.successGreen
            : progress >= 0.3
                ? AppTheme.warningOrange
                : AppTheme.errorRed;

    return GestureDetector(
      onTap: canEdit ? onTap : null,
      onLongPress: (canEdit && (onEditTap != null || onDeleteTap != null))
          ? () => showModalBottomSheet(
                context: context,
                builder: (_) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEditTap != null)
                        ListTile(
                          leading: const Icon(LucideIcons.pencil),
                          title: const Text('Edit Key Result'),
                          onTap: () { Navigator.pop(context); onEditTap!(); },
                        ),
                      if (onDeleteTap != null)
                        ListTile(
                          leading: const Icon(LucideIcons.trash2, color: Colors.red),
                          title: const Text('Delete Key Result', style: TextStyle(color: Colors.red)),
                          onTap: () { Navigator.pop(context); onDeleteTap!(); },
                        ),
                    ],
                  ),
                ),
              )
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  keyResult.completed ? LucideIcons.checkCircle : LucideIcons.circle,
                  size: 14,
                  color: keyResult.completed ? AppTheme.successGreen : Colors.grey[400],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    keyResult.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      decoration: keyResult.completed ? TextDecoration.lineThrough : null,
                      color: keyResult.completed ? AppTheme.textSecondary : null,
                    ),
                  ),
                ),
                if (canEdit)
                  const Icon(LucideIcons.pencil, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Text(
                  keyResult.displayValue,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress.clamp(0, 1),
                minHeight: 4,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to update a key result's progress via radio buttons
class UpdateKeyResultDialog extends StatefulWidget {
  final KeyResult keyResult;
  final void Function(double newValue) onUpdate;

  const UpdateKeyResultDialog({
    super.key,
    required this.keyResult,
    required this.onUpdate,
  });

  static Future<void> show(
    BuildContext context,
    KeyResult kr,
    void Function(double) onUpdate,
  ) {
    return showDialog(
      context: context,
      builder: (_) => UpdateKeyResultDialog(keyResult: kr, onUpdate: onUpdate),
    );
  }

  @override
  State<UpdateKeyResultDialog> createState() => _UpdateKeyResultDialogState();
}

class _UpdateKeyResultDialogState extends State<UpdateKeyResultDialog> {
  late double _selectedValue;

  @override
  void initState() {
    super.initState();
    final current = widget.keyResult.currentValue;
    final target = widget.keyResult.targetValue ?? 1;
    if (current <= 0) {
      _selectedValue = 0;
    } else if (current >= target) {
      _selectedValue = target;
    } else {
      _selectedValue = target * 0.5;
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.keyResult.targetValue ?? 1;
    final inProgressValue = target * 0.5;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(LucideIcons.checkSquare, size: 18, color: AppTheme.primaryIndigo),
          const SizedBox(width: 8),
          const Text('Update Progress', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.keyResult.title,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          RadioListTile<double>(
            value: 0,
            groupValue: _selectedValue,
            onChanged: (v) => setState(() => _selectedValue = v!),
            title: const Text('Not Started', style: TextStyle(fontSize: 14)),
            secondary: const Icon(LucideIcons.circle, size: 16, color: AppTheme.textSecondary),
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.primaryIndigo,
          ),
          RadioListTile<double>(
            value: inProgressValue,
            groupValue: _selectedValue,
            onChanged: (v) => setState(() => _selectedValue = v!),
            title: const Text('In Progress', style: TextStyle(fontSize: 14)),
            secondary: const Icon(LucideIcons.timer, size: 16, color: AppTheme.warningOrange),
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.primaryIndigo,
          ),
          RadioListTile<double>(
            value: target,
            groupValue: _selectedValue,
            onChanged: (v) => setState(() => _selectedValue = v!),
            title: const Text('Completed', style: TextStyle(fontSize: 14)),
            secondary: const Icon(LucideIcons.checkCircle, size: 16, color: AppTheme.successGreen),
            contentPadding: EdgeInsets.zero,
            activeColor: AppTheme.primaryIndigo,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onUpdate(_selectedValue);
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryIndigo,
            foregroundColor: Colors.white,
          ),
          child: const Text('Update'),
        ),
      ],
    );
  }
}
