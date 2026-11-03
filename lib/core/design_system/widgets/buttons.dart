import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_colors.dart';
import '../motion.dart';
import '../tokens.dart';

/// Gradient primary action with press scale, haptic feedback and a built-in
/// loading state. Disabled (opacity 0.5) when [onPressed] is null.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  void _handleTap() {
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(
          color: colors.onHero,
          fontWeight: FontWeight.w700,
        );
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = _enabled),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: AppMotion.duration(context, AppMotion.fast),
          curve: AppMotion.curve,
          child: Opacity(
            opacity: widget.onPressed == null ? 0.5 : 1,
            child: SizedBox(
              width: widget.expand ? double.infinity : null,
              height: AppSize.buttonHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: colors.brandGradient,
                  borderRadius: AppRadius.inputBorder,
                  boxShadow: colors.shadowSoft,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: _enabled ? _handleTap : null,
                    borderRadius: AppRadius.inputBorder,
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpace.xl),
                      child: Center(
                        child: widget.loading
                            ? SizedBox.square(
                                dimension: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: colors.onHero,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.icon != null) ...[
                                    Icon(widget.icon,
                                        size: 20, color: colors.onHero),
                                    const SizedBox(width: AppSpace.sm),
                                  ],
                                  Flexible(
                                    child: Text(
                                      widget.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: style,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary action at the standard 52dp button height.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = loading
        ? const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null;
    return SizedBox(
      width: expand ? double.infinity : null,
      height: AppSize.buttonHeight,
      child: icon == null && child == null
          ? OutlinedButton(
              onPressed: enabled ? onPressed : null,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            )
          : OutlinedButton.icon(
              onPressed: enabled ? onPressed : null,
              icon: child ?? Icon(icon, size: 20),
              label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
    );
  }
}

/// Low-emphasis text action. Keeps the 48dp minimum touch target.
class GhostButton extends StatelessWidget {
  const GhostButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: icon == null ? const SizedBox.shrink() : Icon(icon, size: 18),
      label: Text(label),
    );
  }
}
