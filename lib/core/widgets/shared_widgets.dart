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
      color: backgroundColor ?? Theme.of(context).cardColor,
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
            Icon(icon, size: 16, color: color), // UX-audit HH-06: 12 → 16 for field visibility
            const SizedBox(width: AppTheme.spacingXS),
          ],
          Text(
            text,
            style: const TextStyle( // UX-audit HH-06: explicit 12sp bold instead of caption
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ).copyWith(color: color),
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
      icon: Icon(icon, size: isCompact ? 18 : 20), // UX-audit HH-09: compact 16 → 18
      label: Text(
        label,
        style: TextStyle(fontSize: isCompact ? 13 : 14), // UX-audit HH-09: compact 12 → 13
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        minimumSize: isCompact ? const Size(0, 44) : null, // UX-audit HH-09: 44dp min touch target
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? AppTheme.spacingM : AppTheme.spacingL,
          vertical: isCompact ? 10 : AppTheme.spacingM, // UX-audit HH-09: compact 8 → 10
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

/// Consistent status badge with colored dot + text label (#98).
/// Use everywhere: company cards, user rows, action cards, reports.
class StatusBadge extends StatelessWidget {
  final String status;
  final Color? overrideColor;

  const StatusBadge({
    super.key,
    required this.status,
    this.overrideColor,
  });

  Color _colorForStatus(String s) {
    switch (s.toLowerCase()) {
      case 'active':
      case 'completed':
      case 'confirmed':
      case 'approved':
        return AppTheme.successGreen;
      case 'pending':
      case 'draft':
      case 'processing':
        return AppTheme.warningOrange;
      case 'inactive':
      case 'deactivated':
      case 'removed':
      case 'rejected':
        return AppTheme.errorRed;
      case 'in_progress':
      case 'verifying':
      case 'submitted':
        return AppTheme.infoBlue;
      default:
        return AppTheme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = overrideColor ?? _colorForStatus(status);
    // UX-audit #24: AnimatedSwitcher for smooth status badge transitions
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      child: Row(
        key: ValueKey(status), // triggers animation on status change
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10, // UX-audit HH-07: 8 → 10 for field visibility
            height: 10, // UX-audit HH-07: 8 → 10
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
          const SizedBox(width: 8), // UX-audit HH-07: 6 → 8
          Text(
            status.replaceAll('_', ' ').toUpperCase(),
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
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

/// UX-audit #24: Press-scale micro-interaction on any tappable widget.
/// Wraps child with 0.95 scale-down on press, springs back on release.
class PressableButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;

  const PressableButton({
    super.key,
    required this.child,
    this.onPressed,
  });

  @override
  State<PressableButton> createState() => _PressableButtonState();
}

class _PressableButtonState extends State<PressableButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// UX-audit #24: Staggered slide-in animation for list items.
/// Wrap each list item with this — pass the list index for cascaded delay.
class StaggeredListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDuration;

  const StaggeredListItem({
    super.key,
    required this.child,
    required this.index,
    this.baseDuration = const Duration(milliseconds: 60),
  });

  @override
  State<StaggeredListItem> createState() => _StaggeredListItemState();
}

class _StaggeredListItemState extends State<StaggeredListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    final delay = widget.baseDuration * widget.index.clamp(0, 8);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );

    Future.delayed(delay, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => FadeTransition(
        opacity: _fade,
        child: SlideTransition(position: _slide, child: child),
      ),
      child: widget.child,
    );
  }
}