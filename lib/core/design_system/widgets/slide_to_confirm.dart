import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../tokens.dart';

class SlideToConfirm extends StatefulWidget {
  const SlideToConfirm({
    required this.label,
    required this.onConfirmed,
    super.key,
    this.enabled = true,
  });

  final String label;
  final VoidCallback onConfirmed;
  final bool enabled;

  @override
  State<SlideToConfirm> createState() => _SlideToConfirmState();
}

class _SlideToConfirmState extends State<SlideToConfirm> {
  double _progress = 0;
  bool _completed = false;

  void _updateProgress(double delta, double travel) {
    if (!widget.enabled || _completed || travel <= 0) return;
    setState(() => _progress = (_progress + delta / travel).clamp(0, 1));
  }

  void _finish() {
    if (!widget.enabled || _completed) return;
    if (_progress >= 0.9) {
      setState(() {
        _progress = 1;
        _completed = true;
      });
      HapticFeedback.mediumImpact();
      widget.onConfirmed();
    } else {
      setState(() => _progress = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: 'Slide to ${widget.label}',
      onTap: widget.enabled ? widget.onConfirmed : null,
      child: Tooltip(
        message: 'Slide to ${widget.label}',
        child: LayoutBuilder(
          builder: (context, constraints) {
            const thumbSize = AppSize.minTouchTarget;
            final travel = math.max(0.0, constraints.maxWidth - thumbSize);
            return GestureDetector(
              key: const Key('slide-to-confirm'),
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) =>
                  _updateProgress(details.delta.dx, travel),
              onHorizontalDragEnd: (_) => _finish(),
              onHorizontalDragCancel: () {
                if (!_completed && mounted) setState(() => _progress = 0);
              },
              child: Container(
                height: AppSize.buttonHeight,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: AppRadius.pillBorder,
                  border: Border.all(color: colors.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: _progress,
                        heightFactor: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: colors.brandGradient,
                            borderRadius: AppRadius.pillBorder,
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: thumbSize + AppSpace.sm,
                        ),
                        child: Text(
                          'Slide to ${widget.label}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: _progress >= 0.55
                                        ? colors.onHero
                                        : colors.neutral.fg,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: travel * _progress,
                      top: (AppSize.buttonHeight - thumbSize) / 2,
                      child: Container(
                        width: thumbSize,
                        height: thumbSize,
                        decoration: ShapeDecoration(
                          color:
                              widget.enabled ? colors.primary : colors.hairline,
                          shape: const CircleBorder(),
                        ),
                        child: Icon(
                          _completed ? Icons.check : Icons.arrow_forward,
                          color: colors.onHero,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
