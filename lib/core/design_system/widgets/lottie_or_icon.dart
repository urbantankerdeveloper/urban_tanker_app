import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../motion.dart';

/// Lottie animation from [asset], with [fallback] when the file is missing,
/// fails to load, or reduced motion is on. Reduced motion shows a still frame
/// and never loops.
class LottieOrIcon extends StatelessWidget {
  const LottieOrIcon({
    required this.asset,
    required this.fallback,
    super.key,
    this.size = 96,
    this.repeat = true,
  });

  /// Asset path under `assets/lottie/`, for example `assets/lottie/success.json`.
  final String asset;

  /// Shown instead of the animation: an icon or an indicator.
  final Widget fallback;
  final double size;
  final bool repeat;

  @override
  Widget build(BuildContext context) {
    final still =
        SizedBox.square(dimension: size, child: Center(child: fallback));
    if (AppMotion.reduced(context)) return still;
    return SizedBox.square(
      dimension: size,
      child: RepaintBoundary(
        child: Lottie.asset(
          asset,
          width: size,
          height: size,
          repeat: repeat,
          errorBuilder: (context, error, stackTrace) => still,
        ),
      ),
    );
  }
}
