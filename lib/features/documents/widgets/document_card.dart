import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/models/models.dart';

class DocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback onTap;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFileIcon(),
              const SizedBox(width: 12),
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _categoryColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _categoryIcon,
        color: _categoryColor,
        size: 22,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                document.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _buildVersionBadge(),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            if (document.subcategory != null) ...[
              Text(
                document.subcategory!,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const Text(' · ',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
            Text(
              document.fileSizeDisplay,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const Text(' · ',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            Text(
              timeago.format(document.createdAt),
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            _buildStatusBadge(),
            if (document.isExpiringSoon) ...[
              const SizedBox(width: 6),
              _buildExpiryBadge(),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildVersionBadge() {
    if (document.versionNumber <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'v${document.versionNumber}',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryIndigo,
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            document.approvalStatus.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryBadge() {
    final daysLeft = document.expiresAt!.difference(DateTime.now()).inDays;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.warningOrange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.clock, size: 11, color: AppTheme.warningOrange),
          const SizedBox(width: 3),
          Text(
            daysLeft == 0 ? 'Expires today' : 'Expires in ${daysLeft}d',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.warningOrange,
            ),
          ),
        ],
      ),
    );
  }

  Color get _categoryColor {
    switch (document.category) {
      case DocumentCategory.legalStatutory: return const Color(0xFF7B1FA2);
      case DocumentCategory.technicalDrawings: return AppTheme.primaryIndigo;
      case DocumentCategory.qualityCertificates: return AppTheme.successGreen;
      case DocumentCategory.contractsFinancial: return const Color(0xFFE65100);
      case DocumentCategory.progressReports: return const Color(0xFF0277BD);
      default: return AppTheme.textSecondary;
    }
  }

  IconData get _categoryIcon {
    switch (document.category) {
      case DocumentCategory.legalStatutory: return LucideIcons.scale;
      case DocumentCategory.technicalDrawings: return LucideIcons.penTool;
      case DocumentCategory.qualityCertificates: return LucideIcons.award;
      case DocumentCategory.contractsFinancial: return LucideIcons.fileText;
      case DocumentCategory.progressReports: return LucideIcons.barChart2;
      default: return LucideIcons.file;
    }
  }

  Color get _statusColor {
    switch (document.approvalStatus) {
      case DocumentApprovalStatus.approved: return AppTheme.successGreen;
      case DocumentApprovalStatus.pendingApproval: return AppTheme.warningOrange;
      case DocumentApprovalStatus.rejected: return AppTheme.errorRed;
      case DocumentApprovalStatus.changesRequested: return const Color(0xFF6A1B9A);
      default: return AppTheme.textSecondary;
    }
  }
}
