import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Motion tokens and helpers. Every animation should go through this class so
/// reduced motion (system "remove animations") is honored in one place.
abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  static const curve = Curves.easeOutCubic;
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// Cap on staggered items, so long lists do not wait to finish entering.
  static const maxStaggerItems = 8;
  static const staggerStep = Duration(milliseconds: 50);

  /// True when the system asks for reduced motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d] normally; near-zero when reduced motion is on.
  static Duration duration(BuildContext context, Duration d) =>
      reduced(context) ? const Duration(milliseconds: 1) : d;

  /// Entrance delay for the item at [index], capped at [maxStaggerItems].
  static Duration stagger(int index) =>
      staggerStep * math.min(index, maxStaggerItems);
}

extension AppMotionEntrance on Widget {
  /// Fades and slides this widget in, staggered by [index]. Returns the widget
  /// unchanged when reduced motion is on.
  Widget staggeredEntrance(BuildContext context, int index) {
    if (AppMotion.reduced(context)) return this;
    return animate(delay: AppMotion.stagger(index))
        .fadeIn(duration: AppMotion.base, curve: AppMotion.curve)
        .slideY(
          begin: 0.04,
          end: 0,
          duration: AppMotion.base,
          curve: AppMotion.curve,
        );
  }
}
