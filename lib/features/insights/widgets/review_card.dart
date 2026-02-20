import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/services/review_queue_service.dart';

/// Card widget for a single review item in the Review tab.
class ReviewCard extends StatelessWidget {
  final ReviewItem item;
  final VoidCallback onConfirm;
  final VoidCallback onDismiss;
  final VoidCallback? onMerge;

  const ReviewCard({
    super.key,
    required this.item,
    required this.onConfirm,
    required this.onDismiss,
    this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        border: Border.all(
          color: _borderColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with badges
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingM, AppTheme.spacingS,
              AppTheme.spacingM, 0,
            ),
            child: Row(
              children: [
                _buildDomainIcon(),
                const SizedBox(width: AppTheme.spacingS),
                Expanded(
                  child: Text(
                    item.title,
                    style: AppTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ..._buildBadges(),
              ],
            ),
          ),

          // Subtitle / details
          if (item.subtitle != null || item.amount != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingM + 28, 2, AppTheme.spacingM, 0,
              ),
              child: Row(
                children: [
                  if (item.amount != null)
                    Text(
                      NumberFormat.currency(
                        locale: 'en_IN',
                        symbol: '\u20B9',
                        decimalDigits: 0,
                      ).format(item.amount),
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryIndigo,
                      ),
                    ),
                  if (item.amount != null && item.subtitle != null)
                    const Text(' \u2022 '),
                  if (item.subtitle != null)
                    Expanded(
                      child: Text(
                        item.subtitle!,
                        style: AppTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),

          // Missing fields warning
          if (item.isIncomplete)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingM, AppTheme.spacingXS,
                AppTheme.spacingM, 0,
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 14, color: AppTheme.warningOrange),
                  const SizedBox(width: 4),
                  Text(
                    'Missing: ${item.missingFields.join(", ")}',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.warningOrange,
                    ),
                  ),
                ],
              ),
            ),

          // Transcript snippet
          if (item.transcriptSnippet != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingM, AppTheme.spacingXS,
                AppTheme.spacingM, 0,
              ),
              child: Text(
                '"${item.transcriptSnippet}"',
                style: AppTheme.caption.copyWith(fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacingM, AppTheme.spacingXS,
              AppTheme.spacingM, 0,
            ),
            child: Text(
              _formatRelativeTime(item.createdAt),
              style: AppTheme.caption,
            ),
          ),

          const SizedBox(height: AppTheme.spacingS),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: onConfirm,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirm'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.successGreen,
                    ),
                  ),
                ),
                if (item.isPossibleDuplicate && onMerge != null)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: onMerge,
                      icon: const Icon(Icons.merge, size: 18),
                      label: const Text('Merge'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.infoBlue,
                      ),
                    ),
                  ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Dismiss'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.errorRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color get _borderColor {
    if (item.isPossibleDuplicate) return AppTheme.accentAmber;
    if (item.isIncomplete) return AppTheme.errorRed;
    return AppTheme.infoBlue;
  }

  Widget _buildDomainIcon() {
    final (icon, color) = switch (item.domain) {
      'material' => (Icons.inventory_2_outlined, AppTheme.infoBlue),
      'payment' => (Icons.payments_outlined, AppTheme.successGreen),
      _ => (Icons.info_outline, AppTheme.textSecondary),
    };

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(icon, size: 16, color: color),
    );
  }

  List<Widget> _buildBadges() {
    final badges = <Widget>[];

    if (item.isPossibleDuplicate) {
      badges.add(const SizedBox(width: 4));
      badges.add(_badge('DUPLICATE', AppTheme.accentAmber));
    }
    if (item.isIncomplete) {
      badges.add(const SizedBox(width: 4));
      badges.add(_badge('INCOMPLETE', AppTheme.errorRed));
    }
    if (!item.isPossibleDuplicate && !item.isIncomplete) {
      badges.add(const SizedBox(width: 4));
      badges.add(_badge('AI CREATED', AppTheme.infoBlue));
    }

    return badges;
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }
}
