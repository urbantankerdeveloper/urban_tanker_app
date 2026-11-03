import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';

/// Empty state for a vendor list. Kept under this name for existing callers.
class VendorEmpty extends StatelessWidget {
  const VendorEmpty({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: EmptyState(title: message),
      );
}

/// Error state for a vendor screen. [message] is already user-facing text.
class VendorError extends StatelessWidget {
  const VendorError({super.key, required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => ErrorState(
        error: message,
        message: message,
        onRetry: retry,
      );
}

String formatDate(DateTime? value) => value == null
    ? 'Date not set'
    : value.toLocal().toString().split(' ').first;

/// Tone for a verification state such as approved, pending or rejected.
AppTone verificationTone(AppColors colors, String verification) =>
    switch (verification.toLowerCase()) {
      'approved' || 'verified' => colors.success,
      'pending' || 'submitted' => colors.warning,
      'rejected' || 'expired' => colors.danger,
      _ => colors.neutral,
    };
