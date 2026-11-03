import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';

/// Small health indicator. It fades between the success and danger tones
/// when [healthy] changes. The label beside it says the same thing, so colour
/// is never the only cue.
class StatusDot extends StatelessWidget {
  const StatusDot({required this.healthy, super.key, this.size = 10});

  final bool healthy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = healthy ? colors.success.fg : colors.danger.fg;
    return AnimatedContainer(
      duration: AppMotion.duration(context, AppMotion.base),
      curve: AppMotion.curve,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: tone,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: tone.withValues(alpha: 0.35), blurRadius: 6),
        ],
      ),
    );
  }
}
