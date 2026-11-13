import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';

/// Circular logo with a slow "breathing" glow behind it. Only the glow pulses;
/// the logo stays static. With reduced motion on, the glow is fixed at a
/// moderate strength and nothing animates.
class PulsingLogoBadge extends StatefulWidget {
  const PulsingLogoBadge({this.size = 36, super.key});

  final double size;

  @override
  State<PulsingLogoBadge> createState() => _PulsingLogoBadgeState();
}

class _PulsingLogoBadgeState extends State<PulsingLogoBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = widget.size;
    final logo = Padding(
      padding: EdgeInsets.all(size * 0.12),
      child: Image.asset(
        'assets/images/logo.png',
        fit: BoxFit.contain,
        semanticLabel: 'Urban Tanker logo',
      ),
    );
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _curved,
        child: logo,
        builder: (context, child) {
          final t = _curved.value;
          final glowAlpha = 0.15 + 0.25 * t;
          final blur = 6 + 8 * t;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colors.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: glowAlpha),
                  blurRadius: blur,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(child: child),
          );
        },
      ),
    );
  }
}
