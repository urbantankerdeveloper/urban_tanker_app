import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../motion.dart';
import '../tokens.dart';
import 'app_state_view.dart';
import 'buttons.dart';
import 'lottie_or_icon.dart';

/// Centered empty state with a Lottie (`empty.json`) and an icon fallback.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    super.key,
    this.message,
    this.icon = Icons.inbox_outlined,
    this.action,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return _StateLayout(
      visual: LottieOrIcon(
        asset: 'assets/lottie/empty.json',
        fallback: Icon(icon, size: 44, color: context.colors.primary),
      ),
      title: title,
      message: message,
      action: action,
    );
  }
}

/// Error state. Offline errors get their own copy and icon. Other errors go
/// through `friendlyError`, so no raw exception text is shown.
class ErrorState extends StatelessWidget {
  const ErrorState({
    required this.error,
    super.key,
    this.onRetry,
  });

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final offline = AppStateView.isNetworkError(error);
    final colors = context.colors;
    return _StateLayout(
      visual: LottieOrIcon(
        asset: 'assets/lottie/error.json',
        fallback: Icon(
          offline ? Icons.wifi_off_outlined : Icons.error_outline,
          size: 44,
          color: colors.danger.fg,
        ),
      ),
      title: offline ? 'No network connection' : 'Something went wrong',
      message: offline
          ? 'Check your internet connection and try again.'
          : AppStateView.messageFor(error),
      action: onRetry == null
          ? null
          : SecondaryButton(
              label: 'Try again',
              icon: Icons.refresh,
              onPressed: onRetry,
              expand: false,
            ),
    );
  }
}

/// Loading state with a water-drop Lottie (`loading_water.json`) and a spinner
/// fallback.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key, this.message = 'Loading...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _StateLayout(
      visual: LottieOrIcon(
        asset: 'assets/lottie/loading_water.json',
        size: 72,
        // A still icon under reduced motion, since a spinner never stops.
        fallback: AppMotion.reduced(context)
            ? Icon(Icons.water_drop_outlined, size: 40, color: colors.primary)
            : SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: colors.primary,
                ),
              ),
      ),
      title: 'Please wait',
      message: message,
    );
  }
}

class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.visual,
    required this.title,
    this.message,
    this.action,
  });

  final Widget visual;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              visual,
              const SizedBox(height: AppSpace.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (message != null) ...[
                const SizedBox(height: AppSpace.sm),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AppSpace.lg),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
