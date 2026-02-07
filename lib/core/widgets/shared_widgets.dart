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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusS),
        border: Border.all(color: color.withValues(alpha: 0.3)),
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
    IconData icon;

    switch (priority.toLowerCase()) {
      case 'high':
        color = AppTheme.errorRed;
        icon = Icons.arrow_upward;
        break;
      case 'medium':
      case 'med':
        color = AppTheme.warningOrange;
        icon = Icons.remove;
        break;
      case 'low':
        color = AppTheme.successGreen;
        icon = Icons.arrow_downward;
        break;
      default:
        color = AppTheme.textSecondary;
        icon = Icons.remove;
    }

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      radius: 20,
      child: Icon(icon, color: color, size: 20),
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

/// Shimmer loading card for skeleton loading states
class ShimmerLoadingCard extends StatefulWidget {
  final double height;
  final double? width;

  const ShimmerLoadingCard({
    super.key,
    this.height = 100,
    this.width,
  });

  @override
  State<ShimmerLoadingCard> createState() => _ShimmerLoadingCardState();
}

class _ShimmerLoadingCardState extends State<ShimmerLoadingCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingM,
            vertical: AppTheme.spacingS,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusL),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: [
                AppTheme.backgroundGrey,
                AppTheme.surfaceGrey,
                AppTheme.backgroundGrey,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

/// Shimmer loading list — shows multiple shimmer cards
class ShimmerLoadingList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerLoadingList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 100,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return ShimmerLoadingCard(height: itemHeight);
      },
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