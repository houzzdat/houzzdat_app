import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Confirmation dialogs for user management actions.
/// Follows existing AlertDialog patterns in the codebase.
class UserActionDialogs {
  /// Show confirmation dialog for deactivating a user.
  /// Returns true if confirmed, false/null otherwise.
  static Future<bool?> showDeactivateDialog(
    BuildContext context,
    String userName,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.pause_circle, color: AppTheme.warningOrange, size: 28),
            const SizedBox(width: AppTheme.spacingS),
            const Text('Deactivate User?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                children: [
                  TextSpan(
                    text: userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: ' will lose access to this company.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.backgroundGrey,
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.check_circle, AppTheme.successGreen,
                      'All data will be preserved'),
                  const SizedBox(height: AppTheme.spacingS),
                  _buildInfoRow(Icons.check_circle, AppTheme.successGreen,
                      'Can be reactivated anytime'),
                  const SizedBox(height: AppTheme.spacingS),
                  _buildInfoRow(Icons.info, AppTheme.infoBlue,
                      'User will be unassigned from projects'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningOrange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Deactivate User'),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog for removing a user from the company.
  /// Returns true if confirmed, false/null otherwise.
  static Future<bool?> showRemoveDialog(
    BuildContext context,
    String userName,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person_remove, color: AppTheme.errorRed, size: 28),
            const SizedBox(width: AppTheme.spacingS),
            const Expanded(
              child: Text('Remove User from Company?'),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
                children: [
                  TextSpan(
                    text: userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const TextSpan(
                    text: ' will be permanently removed from this company.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(AppTheme.radiusM),
                border: Border.all(
                  color: AppTheme.errorRed.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(Icons.warning, AppTheme.errorRed,
                      'This action cannot be undone'),
                  const SizedBox(height: AppTheme.spacingS),
                  _buildInfoRow(Icons.check_circle, AppTheme.successGreen,
                      'Historical data (voice notes, actions) preserved'),
                  const SizedBox(height: AppTheme.spacingS),
                  _buildInfoRow(Icons.info, AppTheme.infoBlue,
                      'User\'s records will show as "Former Member"'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove User'),
          ),
        ],
      ),
    );
  }

  /// Show confirmation dialog for reactivating a user.
  /// Returns true if confirmed, false/null otherwise.
  static Future<bool?> showActivateDialog(
    BuildContext context,
    String userName,
  ) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.play_circle, color: AppTheme.successGreen, size: 28),
            const SizedBox(width: AppTheme.spacingS),
            const Text('Reactivate User?'),
          ],
        ),
        content: RichText(
          text: TextSpan(
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textPrimary),
            children: [
              TextSpan(
                text: userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(
                text: ' will regain access to this company and can be assigned to projects.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reactivate User'),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoRow(IconData icon, Color color, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppTheme.spacingS),
        Expanded(
          child: Text(
            text,
            style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
