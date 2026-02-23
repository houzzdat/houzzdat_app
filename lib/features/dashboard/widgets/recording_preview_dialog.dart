import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Dialog shown after recording stops, allowing playback preview before submit.
/// Returns `true` if the user confirms, `false`/null if discarded.
class RecordingPreviewDialog extends StatefulWidget {
  final Uint8List audioBytes;
  final Duration recordingDuration;
  final String? contextLabel;

  const RecordingPreviewDialog({
    super.key,
    required this.audioBytes,
    required this.recordingDuration,
    this.contextLabel,
  });

  @override
  State<RecordingPreviewDialog> createState() => _RecordingPreviewDialogState();
}

class _RecordingPreviewDialogState extends State<RecordingPreviewDialog> {
  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mic,
              color: AppTheme.successGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),

          // Title
          const Text(
            'Recording Complete',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          if (widget.contextLabel != null) ...[
            Text(
              widget.contextLabel!,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],

          // Info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.backgroundGrey,
              borderRadius: BorderRadius.circular(AppTheme.radiusM),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _InfoItem(
                  icon: Icons.timer,
                  label: 'Duration',
                  value: _formatDuration(widget.recordingDuration),
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: AppTheme.textSecondary.withValues(alpha: 0.2),
                ),
                _InfoItem(
                  icon: Icons.storage,
                  label: 'Size',
                  value: _formatBytes(widget.audioBytes.length),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'Submit this voice note or discard and re-record?',
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Navigator.pop(context, false),
          icon: const Icon(Icons.delete_outline, size: 18),
          label: const Text('Discard'),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.errorRed,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.send, size: 18),
          label: const Text('Submit'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: AppTheme.caption.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
