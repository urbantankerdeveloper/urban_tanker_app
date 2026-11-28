import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/auth_feature_flags.dart';
import '../../../app/providers.dart';
import '../../../services/api/api_types.dart';
import '../app_colors.dart';
import '../motion.dart';
import '../tokens.dart';
import 'app_scaffold.dart';
import 'app_state_view.dart';
import 'buttons.dart';
import 'lottie_or_icon.dart';
import 'skeleton.dart';
import 'surfaces.dart';

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

/// Branded empty layout used by screens in the opt-in redesign.
class NewUiEmptyState extends StatelessWidget {
  const NewUiEmptyState({
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
    final colors = context.colors;
    return _StateLayout(
      visual: Semantics(
        image: true,
        label: title,
        child: Container(
          width: 96,
          height: 96,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.info.bg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 44, color: colors.info.fg),
        ),
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
    this.message,
    this.onSignIn,
  });

  final Object error;
  final VoidCallback? onRetry;
  final VoidCallback? onSignIn;

  /// Text already written for users. Use it when [error] is only a message
  /// string, since friendlyError would replace it with a generic line.
  final String? message;

  @override
  Widget build(BuildContext context) {
    final newUi = AuthFeatureFlags.newUiEnabled;
    final currentError = error;
    final offline = AppStateView.isNetworkError(currentError);
    final statusCode = currentError is ApiException
        ? currentError.statusCode
        : null;
    final sessionExpired = statusCode == 401;
    final serverProblem = statusCode != null && statusCode >= 500;
    final colors = context.colors;
    final title = offline
        ? newUi
              ? 'No internet connection'
              : 'No network connection'
        : sessionExpired && newUi
        ? 'Session expired'
        : serverProblem && newUi
        ? 'Server problem'
        : 'Something went wrong';
    final description = offline
        ? 'Check your internet connection and try again.'
        : sessionExpired && newUi
        ? 'Your session has expired. Sign in again to continue.'
        : serverProblem && newUi
        ? 'Our server is having trouble. Please try again shortly.'
        : message ?? AppStateView.messageFor(currentError);
    final Widget? action;
    if (sessionExpired && newUi) {
      action = PrimaryButton(
        label: 'Sign in again',
        icon: Icons.login,
        onPressed:
            onSignIn ??
            () => unawaited(
              ProviderScope.containerOf(
                context,
                listen: false,
              ).read(appControllerProvider).signOut(),
            ),
        expand: false,
      );
    } else if (onRetry == null) {
      action = null;
    } else {
      action = SecondaryButton(
        label: 'Try again',
        icon: Icons.refresh,
        onPressed: onRetry,
        expand: false,
      );
    }

    return _StateLayout(
      visual: LottieOrIcon(
        asset: 'assets/lottie/error.json',
        fallback: Icon(
          offline
              ? Icons.wifi_off_outlined
              : sessionExpired && newUi
              ? Icons.lock_clock_outlined
              : serverProblem && newUi
              ? Icons.cloud_off_outlined
              : Icons.error_outline,
          size: 44,
          color: colors.danger.fg,
        ),
      ),
      title: title,
      message: description,
      action: action,
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

class HomeLoadingState extends StatelessWidget {
  const HomeLoadingState({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: AppPageInsets.withSafeAreaBottom(context, AppPageInsets.standard),
    children: [
      const Row(
        children: [
          SkeletonBox(width: 48, height: 48, radius: AppRadius.pill),
          SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 112, height: 14),
                SizedBox(height: AppSpace.sm),
                SkeletonBox(width: 176, height: 20),
              ],
            ),
          ),
          SkeletonBox(width: 44, height: 44, radius: AppRadius.pill),
        ],
      ),
      const SizedBox(height: AppSpace.xl),
      const SkeletonBox(height: 180, radius: AppRadius.card),
      const SizedBox(height: AppSpace.xl),
      const Row(
        children: [
          Expanded(child: SkeletonBox(height: 80, radius: AppRadius.card)),
          SizedBox(width: AppSpace.md),
          Expanded(child: SkeletonBox(height: 80, radius: AppRadius.card)),
          SizedBox(width: AppSpace.md),
          Expanded(child: SkeletonBox(height: 80, radius: AppRadius.card)),
        ],
      ),
      const SizedBox(height: AppSpace.xxl),
      const SkeletonBox(width: 128, height: 20),
      const SizedBox(height: AppSpace.md),
      const Row(
        children: [
          Expanded(child: SkeletonBox(height: 128, radius: AppRadius.card)),
          SizedBox(width: AppSpace.md),
          Expanded(child: SkeletonBox(height: 128, radius: AppRadius.card)),
        ],
      ),
    ],
  );
}

class ListLoadingState extends StatelessWidget {
  const ListLoadingState({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpace.gutter,
          AppSpace.md,
          AppSpace.gutter,
          AppSpace.sm,
        ),
        child: SkeletonBox(height: 44, radius: AppRadius.pill),
      ),
      Expanded(
        child: ListView.separated(
          padding: AppPageInsets.withSafeAreaBottom(
            context,
            AppPageInsets.standard,
          ),
          itemCount: 5,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpace.md),
          itemBuilder: (context, index) =>
              const SkeletonBox(height: 112, radius: AppRadius.card),
        ),
      ),
    ],
  );
}

class TrackingLoadingState extends StatelessWidget {
  const TrackingLoadingState({super.key});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Expanded(flex: 5, child: SkeletonBox(radius: 0)),
      Expanded(
        flex: 4,
        child: ListView(
          padding: AppPageInsets.standard,
          children: const [
            SkeletonBox(width: 148, height: 14),
            SizedBox(height: AppSpace.md),
            SkeletonBox(width: 220, height: 24),
            SizedBox(height: AppSpace.lg),
            SkeletonBox(height: 72, radius: AppRadius.card),
            SizedBox(height: AppSpace.md),
            SkeletonBox(height: 72, radius: AppRadius.card),
          ],
        ),
      ),
    ],
  );
}

enum FailureScreenKind {
  wrongOtp,
  wrongMpin,
  mpinLocked,
  biometric,
  noVendor,
  locationOff,
  deliveryOtp,
}

class FailureStateScreen extends StatelessWidget {
  const FailureStateScreen({
    required this.kind,
    super.key,
    this.message,
    this.onPrimary,
    this.onSecondary,
  });

  final FailureScreenKind kind;
  final String? message;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final (
      title,
      description,
      icon,
      primaryLabel,
      secondaryLabel,
    ) = switch (kind) {
      FailureScreenKind.wrongOtp => (
        'Code not accepted',
        'The verification code is incorrect or has expired. Check it and try again.',
        Icons.password_outlined,
        'Try again',
        'Change number',
      ),
      FailureScreenKind.wrongMpin => (
        'Incorrect MPIN',
        'That MPIN did not match. Try again.',
        Icons.lock_outline,
        'Try again',
        null,
      ),
      FailureScreenKind.mpinLocked => (
        'MPIN temporarily locked',
        'Too many incorrect attempts. Recover your account with a phone verification code.',
        Icons.lock_clock_outlined,
        'Recover account',
        null,
      ),
      FailureScreenKind.biometric => (
        'Fingerprint not verified',
        'We could not verify your fingerprint. Try again or use your MPIN.',
        Icons.fingerprint,
        'Try fingerprint again',
        'Use MPIN',
      ),
      FailureScreenKind.noVendor => (
        'No partner available',
        'We could not find a delivery partner for this request. Try another location or check again later.',
        Icons.local_shipping_outlined,
        'Review booking',
        'Try again later',
      ),
      FailureScreenKind.locationOff => (
        'Location is turned off',
        'Turn on location services or allow Urban Tanker to access your location, then try again.',
        Icons.location_off_outlined,
        'Open location settings',
        null,
      ),
      FailureScreenKind.deliveryOtp => (
        'Delivery code not accepted',
        'The delivery code is incorrect or expired. Confirm the code with the customer and try again.',
        Icons.pin_outlined,
        'Try again',
        null,
      ),
    };

    return AppScaffold(
      title: title,
      body: ListView(
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          SurfaceCard(
            child: Column(
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.danger.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 44, color: colors.danger.fg),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.sm),
                Text(message ?? description, textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          PrimaryButton(
            label: primaryLabel,
            icon: kind == FailureScreenKind.locationOff
                ? Icons.settings_outlined
                : Icons.refresh,
            onPressed: onPrimary,
          ),
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: AppSpace.sm),
            SecondaryButton(label: secondaryLabel, onPressed: onSecondary),
          ],
        ],
      ),
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
