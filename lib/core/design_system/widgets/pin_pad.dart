import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../services/mpin_service.dart';
import '../app_colors.dart';
import '../motion.dart';
import '../tokens.dart';

/// Digit dots and a large circular keypad for entering an MPIN.
///
/// Keys give a light haptic tick. Dots fill as digits are entered. The dots
/// shake whenever [shakeSignal] changes, for example after a wrong MPIN.
/// Set [onDark] when the pad sits on a dark brand surface such as the lock.
class PinPad extends StatefulWidget {
  const PinPad({
    required this.entered,
    required this.onDigit,
    required this.onDelete,
    required this.onSubmit,
    super.key,
    this.canSubmit = false,
    this.shakeSignal = 0,
    this.onDark = false,
    this.submitLabel = 'Submit',
  });

  final int entered;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final bool canSubmit;
  final int shakeSignal;
  final bool onDark;
  final String submitLabel;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
  ];

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  // Starts at the end, so the dots rest at zero offset.
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
    value: 1,
  );

  @override
  void didUpdateWidget(covariant PinPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shakeSignal != widget.shakeSignal) {
      HapticFeedback.heavyImpact();
      if (!AppMotion.reduced(context)) _shake.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  /// Horizontal offset for a damped side-to-side shake.
  double _shakeOffset() {
    final t = _shake.value;
    return math.sin(t * math.pi * 4) * 10 * (1 - t);
  }

  void _digit(String digit) {
    HapticFeedback.selectionClick();
    widget.onDigit(digit);
  }

  void _delete() {
    HapticFeedback.selectionClick();
    widget.onDelete();
  }

  void _submit() {
    HapticFeedback.lightImpact();
    widget.onSubmit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final ink = widget.onDark ? colors.onHero : scheme.onSurface;
    final accent = widget.onDark ? colors.onHero : colors.primary;
    final keyFill =
        widget.onDark ? colors.onHero.withValues(alpha: 0.12) : colors.surface;
    final keyBorder =
        widget.onDark ? colors.onHero.withValues(alpha: 0.28) : colors.hairline;
    final entered = widget.entered;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '$entered of ${MpinService.maxLength} digits entered',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < MpinService.maxLength; i++)
                AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.fast),
                  curve: AppMotion.curve,
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < entered ? accent : Colors.transparent,
                    border: Border.all(color: accent, width: 2),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(_shakeOffset(), 0),
            child: child,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final row in PinPad._rows) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final digit in row)
                      _PinKey(
                        label: digit,
                        ink: ink,
                        fill: keyFill,
                        border: keyBorder,
                        onPressed: () => _digit(digit),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox.square(
                    dimension: 72,
                    child: IconButton(
                      tooltip: 'Delete digit',
                      onPressed: entered == 0 ? null : _delete,
                      icon: Icon(Icons.backspace_outlined, color: ink),
                    ),
                  ),
                  _PinKey(
                    label: '0',
                    ink: ink,
                    fill: keyFill,
                    border: keyBorder,
                    onPressed: () => _digit('0'),
                  ),
                  _SubmitKey(
                    enabled: widget.canSubmit,
                    label: widget.submitLabel,
                    onPressed: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({
    required this.label,
    required this.ink,
    required this.fill,
    required this.border,
    required this.onPressed,
  });

  final String label;
  final Color ink;
  final Color fill;
  final Color border;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Ink(
        width: 72,
        height: 72,
        decoration: ShapeDecoration(
          color: fill,
          shape: CircleBorder(side: BorderSide(color: border)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitKey extends StatelessWidget {
  const _SubmitKey({
    required this.enabled,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Tooltip(
      message: label,
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            width: 72,
            height: 72,
            decoration: ShapeDecoration(
              gradient: colors.brandGradient,
              shape: const CircleBorder(),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: enabled ? onPressed : null,
              child: Icon(Icons.check, color: colors.onHero, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}
