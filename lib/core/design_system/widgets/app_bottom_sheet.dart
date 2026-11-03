import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../tokens.dart';

/// Bottom sheet with the 28dp top radius and a drag handle. Lifts above the
/// keyboard. Use this instead of raw `showModalBottomSheet`.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
}) {
  final colors = context.colors;
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: colors.surface,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetBorder),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: builder(sheetContext),
    ),
  );
}
