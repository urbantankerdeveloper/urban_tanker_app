import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';

/// Soft gradient with slow blobs in brand colors. The blobs drift once over a
/// few seconds and then rest, so no ticker keeps running. Under reduced motion
/// they start at rest.
class BrandBackdrop extends StatefulWidget {
  const BrandBackdrop({required this.child, super.key});

  final Widget child;

  @override
  State<BrandBackdrop> createState() => _BrandBackdropState();
}

class _BrandBackdropState extends State<BrandBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else if (_controller.value == 0 && !_controller.isAnimating) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => CustomPaint(
                painter: _BlobPainter(
                  progress: _controller.value,
                  colors: colors,
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _BlobPainter extends CustomPainter {
  const _BlobPainter({required this.progress, required this.colors});

  final double progress;
  final AppColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = colors.scaffold);
    final angle = progress * 2 * math.pi;
    final wobble = math.sin(angle);
    final drift = math.cos(angle);
    final blobs = [
      (
        center: Offset(
          size.width * (0.18 + 0.04 * wobble),
          size.height * (0.12 + 0.03 * drift),
        ),
        radius: size.width * 0.62,
        color: colors.primary.withValues(alpha: colors.isDark ? 0.18 : 0.20),
      ),
      (
        center: Offset(
          size.width * (0.92 - 0.05 * drift),
          size.height * (0.55 + 0.04 * wobble),
        ),
        radius: size.width * 0.5,
        color: colors.mint.withValues(alpha: colors.isDark ? 0.08 : 0.35),
      ),
      (
        center: Offset(
          size.width * (0.25 + 0.03 * drift),
          size.height * (0.98 - 0.03 * wobble),
        ),
        radius: size.width * 0.55,
        color: colors.primary.withValues(alpha: colors.isDark ? 0.12 : 0.10),
      ),
    ];
    for (final blob in blobs) {
      final shape = Rect.fromCircle(center: blob.center, radius: blob.radius);
      canvas.drawRect(
        shape,
        Paint()
          ..shader = ui.Gradient.radial(
            blob.center,
            blob.radius,
            [blob.color, blob.color.withValues(alpha: 0)],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_BlobPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.colors != colors;
}

/// Frosted, branded cover for the lock screen. It blurs whatever sits beneath
/// it and tints it with the hero gradient.
class BlurredBrandOverlay extends StatelessWidget {
  const BlurredBrandOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gradient = colors.heroGradient;
    return Positioned.fill(
      child: RepaintBoundary(
        child: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    for (final color in gradient.colors)
                      color.withValues(alpha: 0.92),
                  ],
                  begin: gradient.begin,
                  end: gradient.end,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
