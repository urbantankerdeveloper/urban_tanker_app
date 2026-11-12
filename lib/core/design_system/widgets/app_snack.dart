import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';

enum AppSnackVariant { info, success, error }

/// Floating snackbar with an icon and a tone that matches the variant. Use this
/// instead of raw `SnackBar`. Icon and text carry the meaning; color is extra.
void showAppSnack(
  BuildContext context,
  String message, {
  AppSnackVariant variant = AppSnackVariant.info,
  String? actionLabel,
  VoidCallback? onAction,
  IconData? icon,
}) {
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: tone.bg,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.inputBorder,
        side: BorderSide(color: tone.border),
      ),
      content: Row(
        children: [
          Icon(resolvedIcon, color: tone.fg, size: 20),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Text(message, style: TextStyle(color: tone.fg)),
          ),
        ],
      ),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: tone.fg,
              onPressed: onAction ?? () {},
            ),
    ),
  );
}
