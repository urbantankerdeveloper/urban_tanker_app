import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';

/// Dialog with a title, optional message or content, and right-aligned actions.
/// Replaces `AlertDialog`.
class AppDialog extends StatelessWidget {
  const AppDialog({
    required this.title,
    super.key,
    this.message,
    this.content,
    this.actions = const [],
  });

  final String title;
  final String? message;
  final Widget? content;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleLarge),
            if (message != null) ...[
              const SizedBox(height: AppSpace.sm),
              Text(message!, style: theme.textTheme.bodyLarge),
            ],
            if (content != null) ...[
              const SizedBox(height: AppSpace.md),
              content!,
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: AppSpace.xl),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: AppSpace.sm,
                runSpacing: AppSpace.sm,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shows an [AppDialog] and returns the value passed to `Navigator.pop`.
Future<T?> showAppDialog<T>(BuildContext context, {required AppDialog dialog}) {
  return showDialog<T>(context: context, builder: (_) => dialog);
}

/// Yes/no confirmation. Resolves to `true` only when the confirm action is
/// chosen. [destructive] styles the confirm action with the danger tone.
Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final colors = context.colors;
  final confirmed = await showAppDialog<bool>(
    context,
    dialog: AppDialog(
      title: title,
      message: message,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          style: destructive
              ? TextButton.styleFrom(foregroundColor: colors.danger.fg)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
