import 'package:flutter/material.dart';

import '../app_colors.dart';
import '../theme.dart';
import '../tokens.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_list_row.dart';
import '../widgets/app_snack.dart';
import '../widgets/buttons.dart';
import '../widgets/fields.dart';
import '../widgets/identity.dart';
import '../widgets/lottie_or_icon.dart';
import '../widgets/segmented_tabs.dart';
import '../widgets/skeleton.dart';
import '../widgets/stat_card.dart';
import '../widgets/state_views.dart';
import '../widgets/status_chip.dart';
import '../widgets/surfaces.dart';
import '../widgets/timeline.dart';
import '../typography.dart';

/// Debug-only screen that shows every design-system widget in light and dark.
/// Reach it only behind `kDebugMode`. Never ship a route to it in release.
class DesignSystemGallery extends StatelessWidget {
  const DesignSystemGallery({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Design system')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.gutter),
        children: [
          _ThemeSection(label: 'Light', theme: buildLightTheme()),
          const SizedBox(height: AppSpace.xxl),
          _ThemeSection(label: 'Dark', theme: buildDarkTheme()),
        ],
      ),
    );
  }
}

class _ThemeSection extends StatelessWidget {
  const _ThemeSection({required this.label, required this.theme});

  final String label;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: theme,
      child: Builder(
        builder: (context) => ColoredBox(
          color: context.colors.scaffold,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: AppSpace.lg,
              children: [
                Text(label, style: theme.textTheme.headlineMedium),
                const _Group('Status tones', _StatusTones()),
                const _Group('Typography', _TypeScale()),
                const _Group('Surfaces', _Surfaces()),
                const _Group('Stats', _Stats()),
                const _Group('Buttons', _Buttons()),
                const _Group('Fields', _Fields()),
                const _Group('Segmented tabs', _Segments()),
                const _Group('Timeline', _TimelineDemo()),
                const _Group('Feedback', _Feedback()),
                const _Group('Rows and avatars', _Rows()),
                const _Group('States', _States()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.title, this.child);

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: AppSpace.sm),
        child,
      ],
    );
  }
}

class _StatusTones extends StatelessWidget {
  const _StatusTones();

  @override
  Widget build(BuildContext context) {
    const statuses = [
      'pending',
      'pending_vendor',
      'accepted',
      'assigned',
      'in_transit',
      'delivered',
      'cancelled',
      'rejected',
      'completed',
    ];
    final colors = context.colors;
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        for (final status in statuses) BookingStatusChip(status: status),
        StatusChip(label: 'Success', tone: colors.success),
        StatusChip(label: 'Warning', tone: colors.warning),
        StatusChip(label: 'Danger', tone: colors.danger),
        StatusChip(label: 'Info', tone: colors.info),
      ],
    );
  }
}

class _TypeScale extends StatelessWidget {
  const _TypeScale();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Display 32', style: t.displaySmall),
        Text('Title 1 · 24', style: t.headlineMedium),
        Text('Title 2 · 20', style: t.titleLarge),
        Text('Title 3 · 17', style: t.titleMedium),
        Text('Body 15 · the quick brown fox', style: t.bodyLarge),
        Text('Body small 13 · the quick brown fox', style: t.bodyMedium),
        Text('Label 12', style: t.labelLarge),
        Text('Overline 11', style: t.labelSmall),
        AmountText('₹12,450', large: true),
        AmountText('₹1,08,000', style: AppTypography.numeric(t.titleMedium!)),
      ],
    );
  }
}

class _Surfaces extends StatelessWidget {
  const _Surfaces();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SurfaceCard(child: Text('Surface card')),
        const SizedBox(height: AppSpace.md),
        const GradientCard(child: Text('Gradient card, next delivery')),
        const SizedBox(height: AppSpace.md),
        const GlassCard(child: Text('Glass card with blur')),
        const SizedBox(height: AppSpace.md),
        const GlassCard(blur: false, child: Text('Glass card, solid fallback')),
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Deliveries',
            value: '128',
            delta: '+12%',
            deltaUp: true,
            sparkline: [3, 5, 4, 7, 6, 9],
            icon: Icons.local_shipping_outlined,
          ),
        ),
        SizedBox(width: AppSpace.md),
        Expanded(
          child: StatCard(
            label: 'Cancelled',
            value: '4',
            delta: '-2%',
            deltaUp: false,
          ),
        ),
      ],
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppSpace.md,
      children: [
        PrimaryButton(
          label: 'Book a tanker',
          icon: Icons.local_shipping_outlined,
          onPressed: () {},
        ),
        const PrimaryButton(label: 'Loading', loading: true, onPressed: null),
        const PrimaryButton(label: 'Disabled', onPressed: null),
        SecondaryButton(label: 'Track order', onPressed: () {}),
        GhostButton(
            label: 'Need help?', icon: Icons.help_outline, onPressed: () {}),
      ],
    );
  }
}

class _Fields extends StatelessWidget {
  const _Fields();

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: AppSpace.md,
      children: [
        AppTextField(
          label: 'Phone number',
          helper: 'With country code',
          prefix: const Icon(Icons.phone_outlined),
          keyboardType: TextInputType.phone,
        ),
        OtpField(onChanged: (_) {}),
      ],
    );
  }
}

class _Segments extends StatefulWidget {
  const _Segments();

  @override
  State<_Segments> createState() => _SegmentsState();
}

class _SegmentsState extends State<_Segments> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return SegmentedTabs(
      labels: const ['Active', 'Past'],
      selectedIndex: _index,
      onChanged: (index) => setState(() => _index = index),
    );
  }
}

class _TimelineDemo extends StatelessWidget {
  const _TimelineDemo();

  @override
  Widget build(BuildContext context) {
    return const Timeline(
      steps: [
        TimelineStep(title: 'Order placed', state: TimelineState.done),
        TimelineStep(
          title: 'Vendor assigned',
          subtitle: 'Water Tanker 12K',
          state: TimelineState.current,
        ),
        TimelineStep(title: 'Delivered', state: TimelineState.upcoming),
      ],
    );
  }
}

class _Feedback extends StatelessWidget {
  const _Feedback();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpace.sm,
      runSpacing: AppSpace.sm,
      children: [
        SecondaryButton(
          label: 'Info snack',
          expand: false,
          onPressed: () => showAppSnack(context, 'Booking updated.'),
        ),
        SecondaryButton(
          label: 'Success snack',
          expand: false,
          onPressed: () => showAppSnack(
            context,
            'Payment received.',
            variant: AppSnackVariant.success,
          ),
        ),
        SecondaryButton(
          label: 'Error snack',
          expand: false,
          onPressed: () => showAppSnack(
            context,
            'Could not send the OTP.',
            variant: AppSnackVariant.error,
            actionLabel: 'Retry',
            onAction: () {},
          ),
        ),
        SecondaryButton(
          label: 'Sheet',
          expand: false,
          onPressed: () => showAppBottomSheet<void>(
            context,
            builder: (_) => const Padding(
              padding: EdgeInsets.all(AppSpace.xl),
              child: Text('Bottom sheet, 28dp top radius'),
            ),
          ),
        ),
        SecondaryButton(
          label: 'Confirm',
          expand: false,
          onPressed: () => showAppConfirmDialog(
            context,
            title: 'Sign out?',
            message: 'You will need your MPIN to sign back in.',
            confirmLabel: 'Sign out',
            destructive: true,
          ),
        ),
      ],
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppListRow(
          leading: const AppAvatar(name: 'Mahesh Kumar'),
          title: 'Mahesh Kumar',
          subtitle: 'Customer',
          trailing: const Icon(Icons.chevron_right),
          onTap: () {},
        ),
        const AppListRow(title: 'Row without leading icon'),
      ],
    );
  }
}

class _States extends StatelessWidget {
  const _States();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SkeletonList(itemCount: 2, itemHeight: 64),
        const SizedBox(height: AppSpace.md),
        const Row(
          children: [
            LottieOrIcon(
              asset: 'assets/lottie/success.json',
              fallback: Icon(Icons.check_circle_outline, size: 48),
              size: 72,
            ),
            SizedBox(width: AppSpace.lg),
            Expanded(
                child: Text(
                    'Lottie falls back to an icon when the file is absent.')),
          ],
        ),
        EmptyState(
          title: 'No bookings yet',
          message: 'Book your first tanker to see it here.',
          action: PrimaryButton(label: 'Book a tanker', onPressed: () {}),
        ),
        ErrorState(error: Exception('boom'), onRetry: () {}),
        const LoadingState(),
      ],
    );
  }
}
