import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';
import '../typography.dart';
import 'surfaces.dart';

/// KPI tile: label, animated-friendly value, optional delta with an arrow icon
/// (never color alone), and an optional sparkline drawn with CustomPainter.
class StatCard extends StatelessWidget {
  const StatCard({
    required this.label,
    required this.value,
    super.key,
    this.delta,
    this.deltaUp,
    this.sparkline,
    this.icon,
  });

  final String label;
  final String value;

  /// Text such as "+12%". Shown with an up or down arrow when [deltaUp] is set.
  final String? delta;
  final bool? deltaUp;
  final List<double>? sparkline;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final up = deltaUp;
    final deltaTone = up == null
        ? colors.neutral
        : up
            ? colors.success
            : colors.danger;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: colors.primary),
                const SizedBox(width: AppSpace.sm),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.numeric(theme.textTheme.titleLarge!),
          ),
          if (delta != null) ...[
            const SizedBox(height: AppSpace.xs),
            Row(
              children: [
                if (up != null)
                  Icon(
                    up ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: deltaTone.fg,
                  ),
                if (up != null) const SizedBox(width: AppSpace.xs),
                Flexible(
                  child: Text(
                    delta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: deltaTone.fg,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (sparkline != null && sparkline!.length > 1) ...[
            const SizedBox(height: AppSpace.md),
            SizedBox(
              height: 36,
              width: double.infinity,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: SparklinePainter(
                    values: sparkline!,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Draws a smooth line through [values], scaled to fit. No chart package.
class SparklinePainter extends CustomPainter {
  const SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final range = (max - min) == 0 ? 1.0 : max - min;
    final dx = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * dx;
      final y = size.height - ((values[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(SparklinePainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
