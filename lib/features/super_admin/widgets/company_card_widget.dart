import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Card widget for displaying company information in the super admin panel.
/// Follows the same Card pattern as TeamCardWidget.
class CompanyCardWidget extends StatelessWidget {
  final Map<String, dynamic> company;
  final int userCount;
  final VoidCallback? onDeactivate;
  final VoidCallback? onActivate;
  final VoidCallback? onArchive;
  final VoidCallback? onViewDetails;

  const CompanyCardWidget({
    super.key,
    required this.company,
    this.userCount = 0,
    this.onDeactivate,
    this.onActivate,
    this.onArchive,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final companyName =
        company['company_name']?.toString() ?? 'Unknown Company';
    final status = company['status']?.toString() ?? 'active';
    final createdAt = company['created_at'] != null
        ? DateTime.tryParse(company['created_at'].toString())
        : null;
    final deactivatedAt = company['deactivated_at'] != null
        ? DateTime.tryParse(company['deactivated_at'].toString())
        : null;
    final transcriptionProvider =
        company['transcription_provider']?.toString() ?? 'groq';

    final isActive = status == 'active';
    final isArchived = status == 'archived';

    return AnimatedOpacity(
      opacity: isActive ? 1.0 : 0.8,
      duration: const Duration(milliseconds: 200),
      child: Card(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
        elevation: isActive ? 2 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusM),
          side: BorderSide(
            color: isArchived
                ? AppTheme.warningOrange.withValues(alpha: 0.3)
                : isActive
                    ? Colors.transparent
                    : AppTheme.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Avatar + Info + Actions
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Company avatar with status dot
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor:
                            AppTheme.primaryIndigo.withValues(alpha: 0.1),
                        child: Text(
                          companyName.isNotEmpty
                              ? companyName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryIndigo,
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _getStatusColor(status),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppTheme.spacingM),

                  // Company info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companyName,
                          style: AppTheme.headingSmall.copyWith(
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            _buildStatusBadge(status),
                            const SizedBox(width: AppTheme.spacingS),
                            Icon(
                              Icons.people,
                              size: 14,
                              color: AppTheme.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$userCount user${userCount == 1 ? '' : 's'}',
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Actions menu
                  if (!isArchived)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: AppTheme.textSecondary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusM),
                      ),
                      onSelected: (value) {
                        switch (value) {
                          case 'deactivate':
                            onDeactivate?.call();
                            break;
                          case 'activate':
                            onActivate?.call();
                            break;
                          case 'archive':
                            onArchive?.call();
                            break;
                          case 'details':
                            onViewDetails?.call();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        if (onViewDetails != null)
                          const PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                Icon(Icons.visibility, size: 20),
                                SizedBox(width: 8),
                                Text('View Details'),
                              ],
                            ),
                          ),
                        if (isActive && onDeactivate != null)
                          const PopupMenuItem(
                            value: 'deactivate',
                            child: Row(
                              children: [
                                Icon(Icons.pause_circle,
                                    size: 20, color: AppTheme.warningOrange),
                                SizedBox(width: 8),
                                Text('Deactivate'),
                              ],
                            ),
                          ),
                        if (!isActive && onActivate != null)
                          const PopupMenuItem(
                            value: 'activate',
                            child: Row(
                              children: [
                                Icon(Icons.play_circle,
                                    size: 20, color: AppTheme.successGreen),
                                SizedBox(width: 8),
                                Text('Activate'),
                              ],
                            ),
                          ),
                        if (onArchive != null)
                          const PopupMenuItem(
                            value: 'archive',
                            child: Row(
                              children: [
                                Icon(Icons.archive,
                                    size: 20, color: AppTheme.errorRed),
                                SizedBox(width: 8),
                                Text('Archive'),
                              ],
                            ),
                          ),
                      ],
                    )
                  else
                    // Archived companies only get view details
                    IconButton(
                      icon: const Icon(Icons.visibility,
                          color: AppTheme.textSecondary),
                      onPressed: onViewDetails,
                      tooltip: 'View Details',
                    ),
                ],
              ),

              const SizedBox(height: AppTheme.spacingM),
              const Divider(height: 1),
              const SizedBox(height: AppTheme.spacingS),

              // Bottom info row
              Row(
                children: [
                  // Transcription provider
                  Icon(Icons.record_voice_over,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    _getProviderLabel(transcriptionProvider),
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),

                  // Date info
                  Icon(Icons.calendar_today,
                      size: 14, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  if (deactivatedAt != null && !isActive)
                    Text(
                      '${isArchived ? "Archived" : "Deactivated"} ${DateFormat('MMM d, yyyy').format(deactivatedAt)}',
                      style: AppTheme.bodySmall.copyWith(
                        color: isArchived
                            ? AppTheme.warningOrange
                            : AppTheme.textSecondary,
                      ),
                    )
                  else if (createdAt != null)
                    Text(
                      'Created ${DateFormat('MMM d, yyyy').format(createdAt)}',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = AppTheme.successGreen.withValues(alpha: 0.1);
        textColor = AppTheme.successGreen;
        label = 'ACTIVE';
        break;
      case 'inactive':
        bgColor = AppTheme.textSecondary.withValues(alpha: 0.1);
        textColor = AppTheme.textSecondary;
        label = 'INACTIVE';
        break;
      case 'archived':
        bgColor = AppTheme.warningOrange.withValues(alpha: 0.1);
        textColor = AppTheme.warningOrange;
        label = 'ARCHIVED';
        break;
      default:
        bgColor = AppTheme.textSecondary.withValues(alpha: 0.1);
        textColor = AppTheme.textSecondary;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppTheme.successGreen;
      case 'inactive':
        return AppTheme.textSecondary;
      case 'archived':
        return AppTheme.warningOrange;
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getProviderLabel(String provider) {
    switch (provider) {
      case 'groq':
        return 'Groq Whisper';
      case 'openai':
        return 'OpenAI Whisper';
      case 'gemini':
        return 'Gemini Flash';
      default:
        return provider;
    }
  }
}
