import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';

/// A card widget displaying a report summary in the saved reports list.
class ReportCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const ReportCard({
    super.key,
    required this.report,
    required this.onTap,
    this.onDelete,
  });

  String get _dateLabel {
    final startDate = report['start_date']?.toString() ?? '';
    final endDate = report['end_date']?.toString() ?? '';
    final reportType = report['report_type']?.toString() ?? 'daily';

    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      final fmt = DateFormat('d MMM yyyy');

      if (reportType == 'daily' || startDate == endDate) {
        return 'Daily Report \u2014 ${fmt.format(start)}';
      } else {
        return 'Report \u2014 ${fmt.format(start)} to ${fmt.format(end)}';
      }
    } catch (_) {
      return 'Report \u2014 $startDate';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'final':
        return AppTheme.accentAmber;
      case 'sent':
        return AppTheme.successGreen;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'final':
        return 'Final';
      case 'sent':
        return 'Sent';
      default:
        return 'Draft';
    }
  }

  bool get _canDelete {
    final mgrStatus = report['manager_report_status']?.toString() ?? 'draft';
    final ownerStatus = report['owner_report_status']?.toString() ?? 'draft';
    return mgrStatus == 'draft' && ownerStatus == 'draft';
  }

  @override
  Widget build(BuildContext context) {
    final reportType = report['report_type']?.toString() ?? 'daily';
    final mgrStatus = report['manager_report_status']?.toString() ?? 'draft';
    final ownerStatus = report['owner_report_status']?.toString() ?? 'draft';
    final createdBy = report['users']?['full_name']?.toString() ?? 'Unknown';
    final createdAt = report['created_at']?.toString() ?? '';
    final sentAt = report['sent_at']?.toString();
    final generationTime = report['generation_time_ms'] as int?;

    String timeAgo = '';
    try {
      final dt = DateTime.parse(createdAt);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) {
        timeAgo = '${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        timeAgo = '${diff.inHours}h ago';
      } else {
        timeAgo = DateFormat('d MMM, h:mm a').format(dt);
      }
    } catch (_) {}

    return GestureDetector(
      onTap: onTap,
      onLongPress: _canDelete && onDelete != null
          ? () => _showDeleteMenu(context)
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingM,
          vertical: AppTheme.spacingXS,
        ),
        padding: const EdgeInsets.all(AppTheme.spacingM),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(
            color: ownerStatus == 'sent'
                ? AppTheme.successGreen.withValues(alpha: 0.3)
                : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusM),
                  ),
                  child: const Icon(
                    Icons.assessment_outlined,
                    color: AppTheme.primaryIndigo,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _dateLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'By $createdBy \u2022 $timeAgo',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                ),
                CategoryBadge(
                  text: reportType == 'daily'
                      ? 'Daily'
                      : reportType == 'weekly'
                          ? 'Weekly'
                          : 'Custom',
                  color: AppTheme.infoBlue,
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spacingS),

            // Status badges row
            Row(
              children: [
                _StatusChip(
                  label: 'Manager: ${_statusLabel(mgrStatus)}',
                  color: _statusColor(mgrStatus),
                ),
                const SizedBox(width: AppTheme.spacingS),
                _StatusChip(
                  label: 'Owner: ${_statusLabel(ownerStatus)}',
                  color: _statusColor(ownerStatus),
                ),
                const Spacer(),
                if (sentAt != null)
                  Text(
                    'Sent ${_formatSentDate(sentAt)}',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (generationTime != null && sentAt == null)
                  Text(
                    'AI: ${(generationTime / 1000).toStringAsFixed(1)}s',
                    style: AppTheme.caption,
                  ),
              ],
            ),

            // Arrow indicator
            const SizedBox(height: AppTheme.spacingXS),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.chevron_right,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSentDate(String sentAt) {
    try {
      final dt = DateTime.parse(sentAt);
      return DateFormat('d MMM, h:mm a').format(dt);
    } catch (_) {
      return sentAt;
    }
  }

  void _showDeleteMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
              title: const Text('Delete Report'),
              subtitle: const Text('This draft report will be permanently deleted'),
              onTap: () {
                Navigator.pop(ctx);
                onDelete?.call();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
