import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';

/// Brand mark on a soft teal glow. It fades and scales in once, unless reduced
/// motion is on.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 84});

  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final logo = Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.16),
      decoration: BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.35),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Image.asset(
        'assets/images/logo_white.png',
        fit: BoxFit.contain,
        semanticLabel: 'Urban Tanker logo',
      ),
    );
    if (AppMotion.reduced(context)) return logo;
    // TweenAnimationBuilder rather than flutter_animate: it schedules no timers.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: AppMotion.slow,
      curve: AppMotion.curve,
      child: logo,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
      ),
    );
  }
}
