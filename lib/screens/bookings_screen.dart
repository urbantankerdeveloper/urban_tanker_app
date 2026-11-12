import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/design_system/design_system.dart';
import '../models/booking.dart';
import 'booking_details_screen.dart';
import 'common/booking_format.dart';

/// Bookings tab. Active and Past filter the bookings loaded so far. More pages
/// load as the list nears its end.
class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({this.onBookAgain, super.key});

  final Future<void> Function(Booking booking)? onBookAgain;

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  final _scrollController = ScrollController();
  int _filter = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_loadMoreNearEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(ref.read(bookingsProvider.notifier).loadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookings = ref.watch(bookingsProvider);
    return bookings.when(
      loading: () => const LoadingState(message: 'Loading your bookings...'),
      error: (error, _) => ErrorState(
        error: error,
        onRetry: () => ref.invalidate(bookingsProvider),
      ),
      data: (page) {
        if (page.items.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No bookings yet',
            message: 'Your bookings will appear here.',
          );
        }
        final shown = [
          for (final booking in page.items)
            if (isActiveBooking(booking) == (_filter == 0)) booking,
        ];
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.gutter,
                AppSpace.md,
                AppSpace.gutter,
                AppSpace.sm,
              ),
              child: SegmentedTabs(
                labels: const ['Active', 'Past'],
                selectedIndex: _filter,
                onChanged: (index) => setState(() => _filter = index),
              ),
            ),
            Expanded(
              child: shown.isEmpty && !page.hasMore
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: _filter == 0
                          ? 'No active bookings'
                          : 'No past bookings',
                      message: _filter == 0
                          ? 'Bookings show here until they are delivered.'
                          : 'Finished and cancelled bookings show here.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(bookingsProvider),
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: AppPageInsets.withSafeAreaBottom(
                          context,
                          AppPageInsets.standard,
                        ),
                        itemCount: shown.length + (page.hasMore ? 1 : 0),
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: AppSpace.md),
                        itemBuilder: (context, index) {
                          if (index == shown.length) {
                            return _BookingsFooter(
                              failed: page.loadMoreFailed,
                              onVisible: () => unawaited(
                                ref.read(bookingsProvider.notifier).loadMore(),
                              ),
                              onRetry: () => ref
                                  .read(bookingsProvider.notifier)
                                  .retryLoadMore(),
                            );
                          }
                          return _BookingCard(
                            booking: shown[index],
                            onOpen: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BookingDetailsScreen(
                                  booking: shown[index],
                                  onBookAgain: widget.onBookAgain,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Shown as the last list row while more bookings exist. Asks for the next
/// page once it is built, which covers lists too short to scroll.
class _BookingsFooter extends StatefulWidget {
  const _BookingsFooter({
    required this.failed,
    required this.onVisible,
    required this.onRetry,
  });

  final bool failed;
  final VoidCallback onVisible;
  final VoidCallback onRetry;

  @override
  State<_BookingsFooter> createState() => _BookingsFooterState();
}

class _BookingsFooterState extends State<_BookingsFooter> {
  @override
  void initState() {
    super.initState();
    if (!widget.failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onVisible();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.failed) {
      return Center(
        child: TextButton(
          onPressed: widget.onRetry,
          child: const Text("Couldn't load more. Tap to retry."),
        ),
      );
    }
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Center(
        child: SizedBox.square(
          dimension: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onOpen,
  });

  final Booking booking;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amount = booking.quotedAmountRupees;
    final details = [
      booking.location,
      if (booking.deliveryDate != null) formatBookingDate(booking.deliveryDate),
    ];
    return SurfaceCard(
      padding: AppPageInsets.card,
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton(
                    onPressed: onOpen,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      booking.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              BookingStatusChip(status: booking.status),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          for (final line in details)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.xs),
              child: Text(
                line,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          if (amount != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.sm),
              child: Row(
                children: [
                  AmountText(
                    '₹${amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
