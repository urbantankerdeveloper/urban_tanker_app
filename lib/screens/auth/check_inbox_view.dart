import 'package:flutter/material.dart';

import '../../core/design_system/design_system.dart';

/// Shown after an email sign-up that needs the confirmation link. It replaces
/// the form, so the user knows where to look next.
///
/// There is no "open mail app" button: url_launcher is not a dependency, so the
/// screen gives a plain hint. There is no resend button either, because the
/// backend has no resend endpoint for confirmation links yet.
class CheckInboxView extends StatelessWidget {
  const CheckInboxView({
    required this.email,
    required this.onBackToSignIn,
    super.key,
  });

  final String email;
  final VoidCallback onBackToSignIn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: LottieOrIcon(
            asset: 'assets/lottie/mail.json',
            repeat: false,
            fallback: Icon(
              Icons.mark_email_unread_outlined,
              size: 56,
              color: colors.primary,
            ),
            size: 120,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          'Check your inbox',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpace.sm),
        Text(
          email,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: colors.primary),
        ),
        const SizedBox(height: AppSpace.md),
        Text(
          'We sent a confirmation link to this address. Open it to finish '
          'creating your account, then sign in. If it is not in your inbox, '
          'check your spam folder.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpace.xl),
        PrimaryButton(
          label: 'Back to sign in',
          onPressed: onBackToSignIn,
        ),
      ],
    );
  }
}
