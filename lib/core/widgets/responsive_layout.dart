import 'package:flutter/material.dart';

/// PP-11: Responsive layout utilities for tablet optimization.
///
/// Provides breakpoint-aware builders and adaptive containers
/// that switch between phone and tablet layouts.

/// Screen size breakpoints.
class Breakpoints {
  Breakpoints._();

  /// Phone portrait max width.
  static const double phone = 600;

  /// Tablet portrait / phone landscape.
  static const double tablet = 768;

  /// Tablet landscape / desktop.
  static const double desktop = 1024;

  /// Large desktop.
  static const double desktopLarge = 1366;
}

/// Returns the current device type based on width.
enum DeviceType { phone, tablet, desktop }

DeviceType getDeviceType(double width) {
  if (width >= Breakpoints.desktop) return DeviceType.desktop;
  if (width >= Breakpoints.tablet) return DeviceType.tablet;
  return DeviceType.phone;
}

/// A widget that provides different layouts based on screen width.
///
/// Usage:
/// ```dart
/// ResponsiveLayout(
///   phone: (context) => PhoneLayout(),
///   tablet: (context) => TabletLayout(),
/// )
/// ```
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context) phone;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context)? desktop;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final deviceType = getDeviceType(constraints.maxWidth);

        switch (deviceType) {
          case DeviceType.desktop:
            return (desktop ?? tablet ?? phone)(context);
          case DeviceType.tablet:
            return (tablet ?? phone)(context);
          case DeviceType.phone:
            return phone(context);
        }
      },
    );
  }
}

/// A two-column layout for tablet screens.
///
/// Shows [leftChild] and [rightChild] side by side with configurable ratio.
/// Falls back to a single-column [phoneChild] on phones.
class AdaptiveTwoColumn extends StatelessWidget {
  /// Widget to show on phones (single column).
  final Widget phoneChild;

  /// Left panel on tablet/desktop.
  final Widget leftChild;

  /// Right panel on tablet/desktop.
  final Widget rightChild;

  /// Flex ratio for left:right (default 1:1).
  final int leftFlex;
  final int rightFlex;

  /// Spacing between columns.
  final double spacing;

  /// Padding around the columns.
  final EdgeInsets padding;

  const AdaptiveTwoColumn({
    super.key,
    required this.phoneChild,
    required this.leftChild,
    required this.rightChild,
    this.leftFlex = 1,
    this.rightFlex = 1,
    this.spacing = 16,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < Breakpoints.tablet) {
          return phoneChild;
        }

        return Padding(
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: leftFlex, child: leftChild),
              SizedBox(width: spacing),
              Expanded(flex: rightFlex, child: rightChild),
            ],
          ),
        );
      },
    );
  }
}

/// Constrains content width for comfortable reading on wide screens.
///
/// On phones, uses full width. On tablet/desktop, limits content
/// width and optionally centers it.
class ContentConstraint extends StatelessWidget {
  final Widget child;
  final double maxContentWidth;
  final bool center;

  const ContentConstraint({
    super.key,
    required this.child,
    this.maxContentWidth = 800,
    this.center = true,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= maxContentWidth) {
          return child;
        }

        final constrainedChild = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: child,
        );

        return center
            ? Center(child: constrainedChild)
            : constrainedChild;
      },
    );
  }
}

/// Returns the number of grid columns based on screen width.
int responsiveColumnCount(double width) {
  if (width >= Breakpoints.desktopLarge) return 4;
  if (width >= Breakpoints.desktop) return 3;
  if (width >= Breakpoints.tablet) return 2;
  return 1;
}

/// Adaptive grid that adjusts column count based on width.
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;

  const AdaptiveGrid({
    super.key,
    required this.children,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = responsiveColumnCount(constraints.maxWidth);

        if (columns == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
        }

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            final totalSpacing = spacing * (columns - 1);
            final width = (constraints.maxWidth - totalSpacing) / columns;
            return SizedBox(width: width, child: child);
          }).toList(),
        );
      },
    );
  }
}
