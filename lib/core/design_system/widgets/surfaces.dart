import 'dart:ui';

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';

/// Solid card with the card radius and a hairline border (dark) or soft
/// shadow (light). The default container for content.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: colors.hairline),
        boxShadow: colors.shadowSoft,
      ),
      child: _Tappable(
        onTap: onTap,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// Brand-gradient hero card for the main summary on a screen.
/// Text and icons inside use `context.colors.onHero`.
class GradientCard extends StatelessWidget {
  const GradientCard({
    required this.child,
    super.key,
    this.gradient,
    this.padding = const EdgeInsets.all(AppSpace.xl),
    this.onTap,
  });

  final Widget child;
  final LinearGradient? gradient;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient ?? colors.heroGradient,
        borderRadius: AppRadius.cardBorder,
        boxShadow: colors.shadowLifted,
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.onHero),
        child: IconTheme.merge(
          data: IconThemeData(color: colors.onHero),
          child: _Tappable(onTap: onTap, padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Frosted surface for small and medium overlays (nav bar, banners, a summary
/// over a map). Blur is costly, so pass `blur: false` on low-end devices to
/// get a solid fill with the same shape. The effect is wrapped in a
/// RepaintBoundary.
class GlassCard extends StatelessWidget {
  const GlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppSpace.lg),
    this.blur = true,
    this.radius = AppRadius.cardBorder,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool blur;
  final BorderRadius radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final decoration = BoxDecoration(
      color: blur ? colors.glassFill : colors.surface,
      borderRadius: radius,
      border: Border.all(color: colors.glassBorder),
    );
    final content = DecoratedBox(
      decoration: decoration,
      child: _Tappable(onTap: onTap, padding: padding, child: child),
    );
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: blur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                child: content,
              )
            : content,
      ),
    );
  }
}

/// Padding plus an optional InkWell. Used by every card so the tap ripple is
/// clipped to the card shape.
class _Tappable extends StatelessWidget {
  const _Tappable({
    required this.child,
    required this.padding,
    required this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    if (onTap == null) return content;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorder,
        child: content,
      ),
    );
  }
}
