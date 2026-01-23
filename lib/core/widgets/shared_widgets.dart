import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Empty state widget for when no data is available
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: AppTheme.textSecondary),
            const SizedBox(height: AppTheme.spacingM),
            Text(title, style: AppTheme.headingMedium.copyWith(color: AppTheme.textSecondary)),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.spacingS),
              Text(subtitle!, style: AppTheme.bodySmall, textAlign: TextAlign.center),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading indicator widget
class LoadingWidget extends StatelessWidget {
  final String? message;

  const LoadingWidget({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryIndigo),
          if (message != null) ...[
            const SizedBox(height: AppTheme.spacingM),
            Text(message!, style: AppTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// Section header with optional action button
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Color? backgroundColor;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? AppTheme.cardWhite,
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: AppTheme.headingMedium),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Category badge widget
class CategoryBadge extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const CategoryBadge({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: AppTheme.spacingXS),
          ],
          Text(
            text,
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Priority indicator widget
class PriorityIndicator extends StatelessWidget {
  final String priority;

  const PriorityIndicator({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    String emoji;
    
    switch (priority.toLowerCase()) {
      case 'high':
        color = AppTheme.errorRed;
        emoji = '🔴';
        break;
      case 'medium':
      case 'med':
        color = AppTheme.warningOrange;
        emoji = '🟡';
        break;
      case 'low':
        color = AppTheme.successGreen;
        emoji = '🟢';
        break;
      default:
        color = AppTheme.textSecondary;
        emoji = '⚪';
    }

    return CircleAvatar(
      backgroundColor: color,
      radius: 20,
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    );
  }
}

/// Custom action button
class ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final bool isCompact;

  const ActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = AppTheme.accentAmber,
    this.foregroundColor = Colors.black,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: isCompact ? 16 : 20),
      label: Text(
        label,
        style: TextStyle(fontSize: isCompact ? 12 : 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? AppTheme.spacingM : AppTheme.spacingL,
          vertical: isCompact ? AppTheme.spacingS : AppTheme.spacingM,
        ),
      ),
      onPressed: onPressed,
    );
  }
}

/// Error widget
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingXL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: AppTheme.errorRed),
            const SizedBox(height: AppTheme.spacingM),
            Text('Error', style: AppTheme.headingMedium.copyWith(color: AppTheme.errorRed)),
            const SizedBox(height: AppTheme.spacingS),
            Text(message, style: AppTheme.bodyMedium, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spacingL),
              ActionButton(
                label: 'Retry',
                icon: Icons.refresh,
                onPressed: onRetry!,
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
              ),
            ],
          ],
        ),
      ),
    );
  }
}