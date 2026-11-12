import 'dart:async';

import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';
import 'app_snack.dart';

class AppToastAction {
  const AppToastAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool primary;
}

/// Handle for a toast shown by [showAppToast]. Call [dismiss] to remove it
/// early; the toast also removes itself after its auto-dismiss delay.
class AppToast {
  AppToast._(this._onDismissed);

  final VoidCallback? _onDismissed;
  OverlayEntry? _entry;
  Timer? _timer;

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    final entry = _entry;
    if (entry == null) return;
    _entry = null;
    entry.remove();
    _onDismissed?.call();
  }
}

/// Shows a toast in the top-right corner of the root overlay. Unlike
/// [showAppSnack], it can stay open until dismissed and carry action buttons,
/// which is needed for new-order offers.
AppToast showAppToast(
  BuildContext context,
  String message, {
  AppSnackVariant variant = AppSnackVariant.info,
  IconData? icon,
  List<AppToastAction> actions = const [],
  Duration? autoDismissAfter = const Duration(seconds: 4),
  VoidCallback? onDismissed,
}) {
  final toast = AppToast._(onDismissed);
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return toast;

  final colors = context.colors;
  final tone = switch (variant) {
    AppSnackVariant.success => colors.success,
    AppSnackVariant.error => colors.danger,
    AppSnackVariant.info => colors.info,
  };
  final resolvedIcon = icon ??
      switch (variant) {
        AppSnackVariant.success => Icons.check_circle_outline,
        AppSnackVariant.error => Icons.error_outline,
        AppSnackVariant.info => Icons.info_outline,
      };
  final top = MediaQuery.paddingOf(context).top + AppSpace.md;

  final entry = OverlayEntry(
    builder: (_) => Positioned(
      top: top,
      right: AppSpace.md,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Material(
          color: tone.bg,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.inputBorder,
            side: BorderSide(color: tone.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(resolvedIcon, color: tone.fg, size: 20),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Text(message, style: TextStyle(color: tone.fg)),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      visualDensity: VisualDensity.compact,
                      color: tone.fg,
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: toast.dismiss,
                    ),
                  ],
                ),
                if (actions.isNotEmpty)
                  Wrap(
                    spacing: AppSpace.sm,
                    children: [
                      for (final action in actions)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor:
                                action.primary ? tone.bg : tone.fg,
                            backgroundColor:
                                action.primary ? tone.fg : null,
                          ),
                          onPressed: action.onPressed,
                          child: Text(action.label),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  toast._entry = entry;
  overlay.insert(entry);
  if (autoDismissAfter != null) {
    toast._timer = Timer(autoDismissAfter, toast.dismiss);
  }
  return toast;
}
