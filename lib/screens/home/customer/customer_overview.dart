import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/booking.dart';
import '../../../models/service.dart';
import '../../../models/session.dart';
import '../../common/booking_format.dart';

/// Customer Home tab. Shows the next delivery (or a call to book), quick
/// actions, the service grid, and recent bookings. Loading, error and empty
/// states replace the content they belong to.
class CustomerOverview extends ConsumerWidget {
  const CustomerOverview({
    required this.user,
    required this.services,
    required this.loading,
    required this.onRetry,
    required this.onBook,
    required this.onBookAgain,
    required this.onOpenBookings,
    required this.onOpenAccount,
    super.key,
    this.error,
  });

  final SessionUser user;
  final List<TankerService> services;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;

  /// Null while services are loading or empty; disables every booking entry.
  final VoidCallback? onBook;
  final void Function(Booking booking) onBookAgain;
  final VoidCallback onOpenBookings;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider);
    final items = bookings.value?.items ?? const <Booking>[];
    Booking? active;
    for (final booking in items) {
      if (isActiveBooking(booking)) {
        active = booking;
        break;
      }
    }
    final latest = items.isEmpty ? null : items.first;
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(bookingsProvider);
        await onRetry();
      },
      child: ListView(
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          AppHeader(
            greeting: 'Good to see you,',
            title: user.name.split(' ').first,
            avatarName: user.name,
          ),
          const SizedBox(height: AppSpace.xl),
          _HeroCard(active: active, onBook: onBook, onOpen: onOpenBookings),
          const SizedBox(height: AppSpace.xl),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  icon: Icons.replay,
                  label: 'Book again',
                  onTap: latest == null || onBook == null
                      ? null
                      : () => onBookAgain(latest),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: _QuickAction(
                  icon: Icons.receipt_long_outlined,
                  label: 'My bookings',
                  onTap: onOpenBookings,
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: _QuickAction(
                  icon: Icons.support_agent_outlined,
                  label: 'Support',
                  onTap: onOpenAccount,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xxl),
          const SectionHeader(title: 'Services'),
          const SizedBox(height: AppSpace.md),
          _ServiceGrid(
            services: services,
            loading: loading,
            error: error,
            onRetry: onRetry,
            onBook: onBook,
          ),
          const SizedBox(height: AppSpace.xxl),
          _RecentBookings(
            bookings: bookings,
            onOpen: onOpenBookings,
            onRetry: () => ref.invalidate(bookingsProvider),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.active,
    required this.onBook,
    required this.onOpen,
  });

  final Booking? active;
  final VoidCallback? onBook;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final booking = active;
    if (booking == null) {
      return GradientCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('BOOK A TANKER', style: theme.textTheme.labelSmall),
            const SizedBox(height: AppSpace.sm),
            Text(
              'Water when you need it.',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpace.lg),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: colors.onHero,
                foregroundColor: colors.primaryDeep,
              ),
              onPressed: onBook,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Start a booking'),
            ),
          ],
        ),
      );
    }
    return GradientCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT DELIVERY', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpace.sm),
          Text(
            booking.reference,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpace.sm),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BookingStatusChip(status: booking.status),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            booking.location,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: SurfaceCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(
          vertical: AppSpace.md,
          horizontal: AppSpace.xs,
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.primary),
            const SizedBox(height: AppSpace.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({
    required this.services,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onBook,
  });

  final List<TankerService> services;
  final bool loading;
  final String? error;
  final Future<void> Function() onRetry;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _Pairs(
        count: 4,
        builder: _skeletonTile,
      );
    }
    final message = error;
    if (message != null) {
      return ErrorState(
        error: message,
        message: message,
        onRetry: () => onRetry(),
      );
    }
    if (services.isEmpty) {
      return const EmptyState(
        title: 'No services are available right now.',
        icon: Icons.water_drop_outlined,
      );
    }
    return _Pairs(
      count: services.length,
      builder: (context, index) => _ServiceTile(
        service: services[index],
        onTap: onBook,
      ),
    );
  }
}

Widget _skeletonTile(BuildContext context, int index) =>
    const SkeletonBox(height: 128, radius: AppRadius.card);

/// Lays out [count] items two to a row.
class _Pairs extends StatelessWidget {
  const _Pairs({required this.count, required this.builder});

  final int count;
  final Widget Function(BuildContext context, int index) builder;

  @override
  Widget build(BuildContext context) {
    final rows = (count + 1) ~/ 2;
    return Column(
      children: [
        for (var row = 0; row < rows; row++) ...[
          if (row > 0) const SizedBox(height: AppSpace.md),
          Row(
            children: [
              Expanded(child: builder(context, row * 2)),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: row * 2 + 1 < count
                    ? builder(context, row * 2 + 1)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service, required this.onTap});

  final TankerService service;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.mint,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.water_drop_outlined, color: colors.ink),
          ),
          const SizedBox(height: AppSpace.md),
          Text(
            service.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            service.description.isEmpty
                ? service.category
                : service.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _RecentBookings extends StatelessWidget {
  const _RecentBookings({
    required this.bookings,
    required this.onOpen,
    required this.onRetry,
  });

  final AsyncValue<BookingsState> bookings;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return bookings.when(
      loading: () => const SizedBox(
        height: 132,
        child: Row(
          children: [
            Expanded(child: SkeletonBox(height: 132, radius: AppRadius.card)),
            SizedBox(width: AppSpace.md),
            Expanded(child: SkeletonBox(height: 132, radius: AppRadius.card)),
          ],
        ),
      ),
      error: (error, _) => AppStateInline.error(
        error: error,
        onRetry: onRetry,
      ),
      data: (state) {
        final items = state.items.take(5).toList();
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Recent bookings',
              actionLabel: 'See all',
              onAction: onOpen,
            ),
            const SizedBox(height: AppSpace.sm),
            SizedBox(
              height: 128,
              child: ListView.separated(
                padding: AppPageInsets.section.copyWith(top: 0, bottom: 0),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(width: AppSpace.md),
                itemBuilder: (context, index) => SizedBox(
                  width: 220,
                  child: _RecentCard(booking: items[index], onTap: onOpen),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.booking, required this.onTap});

  final Booking booking;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            booking.reference,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpace.sm),
          BookingStatusChip(status: booking.status),
          const SizedBox(height: AppSpace.sm),
          Expanded(
            child: Text(
              booking.location,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
