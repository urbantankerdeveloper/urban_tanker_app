import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../app/providers.dart';
import '../core/design_system/design_system.dart';
import '../models/booking.dart';
import '../models/booking_service_form.dart';
import '../models/payment.dart';
import '../services/friendly_error.dart';
import '../services/payment/online_payment_flow.dart';
import '../services/payment/payment_checkout.dart';
import '../services/realtime_service.dart';
import 'common/booking_format.dart';
import 'common/brand_map.dart';

/// One booking: progress, delivery location, driver, live tracking, order
/// summary, and the actions that the status allows.
class BookingDetailsScreen extends ConsumerStatefulWidget {
  const BookingDetailsScreen({required this.booking, super.key});

  final Booking booking;

  @override
  ConsumerState<BookingDetailsScreen> createState() =>
      _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends ConsumerState<BookingDetailsScreen>
    with WidgetsBindingObserver {
  Booking get booking => widget.booking;

  RealtimeService? _realtime;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  Timer? _refreshTimer;
  bool _liveUpdatesConnected = false;
  bool _inForeground = true;
  String? _liveUpdatesError;
  Future<PaymentReceipt?>? _receiptFuture;
  bool _payingOnline = false;

  static const _payOnlineStatuses = {'pending_vendor', 'vendor_assigned', 'accepted'};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectRealtime();
    _startRefreshTimer();
    _receiptFuture = _loadReceipt();
  }

  /// Polling is only a fallback. It runs while the live connection is down and
  /// the app is in the foreground.
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    if (!_inForeground || _liveUpdatesConnected) return;
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _refreshTracking(),
    );
  }

  void _connectRealtime() {
    try {
      final controller = ref.read(appControllerProvider);
      final realtime = controller.realtime;
      if (realtime == null) {
        setState(() => _liveUpdatesError = 'Realtime connection unavailable.');
        return;
      }
      _realtime = realtime;
      _liveUpdatesConnected = realtime.isConnected;
      _realtimeSubscription = realtime.events.listen(
        (event) => _onRealtimeEvent(event.name, event.payload),
      );
      realtime.joinBooking(widget.booking.id);
    } catch (error) {
      if (mounted) setState(() => _liveUpdatesError = friendlyError(error));
    }
  }

  void _onRealtimeEvent(String event, dynamic payload) {
    if (event == 'disconnect' || event == 'connect_error') {
      if (mounted) {
        setState(() {
          _liveUpdatesConnected = false;
          _liveUpdatesError = payload.toString();
        });
        _startRefreshTimer();
      }
      return;
    }
    if (event == 'connected') {
      _realtime?.joinBooking(widget.booking.id);
      if (mounted) {
        setState(() {
          _liveUpdatesConnected = true;
          _liveUpdatesError = null;
        });
        _startRefreshTimer();
      }
      return;
    }
    if (payload is! Map ||
        payload['bookingId']?.toString() != widget.booking.id) {
      return;
    }
    if (event == 'booking.location.updated' ||
        event == 'booking.updated' ||
        event == 'notification.created') {
      _refreshTracking();
      if (event != 'booking.location.updated') {
        ref.invalidate(bookingsProvider);
      }
    }
  }

  void _refreshTracking() {
    if (!mounted) return;
    ref.invalidate(bookingTrackingProvider(widget.booking.id));
  }

  /// Payment detail for a receipt. A failed lookup is not fatal: the booking
  /// still shows its stored status and the user can retry the check.
  Future<PaymentReceipt?> _loadReceipt() =>
      ref.read(appControllerProvider).api.getPaymentDetails(widget.booking.id);

  void _refreshReceipt() {
    if (!mounted) return;
    setState(() => _receiptFuture = _loadReceipt());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _inForeground = true;
      _refreshTracking();
      _startRefreshTimer();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _inForeground = false;
      _refreshTimer?.cancel();
      _refreshTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _realtimeSubscription?.cancel();
    _realtime?.leaveBooking(widget.booking.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final colors = context.colors;
    final theme = Theme.of(context);
    final tracking = ref.watch(bookingTrackingProvider(booking.id));
    final snapshot = tracking.value;
    final currentStatus = snapshot?.status ?? booking.status;
    final progress = bookingProgressIndex(currentStatus);
    final finished = progress == bookingProgressSteps.length - 1;
    final latitude = booking.latitude;
    final longitude = booking.longitude;
    final changesAllowed = !['delivered', 'cancelled'].contains(currentStatus);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            foregroundColor: colors.onHero,
            actions: [
              IconButton(
                tooltip: 'Refresh tracking',
                onPressed: _refreshTracking,
                icon: const Icon(Icons.refresh),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(
                start: 56,
                end: 56,
                bottom: 14,
              ),
              title: Text(
                booking.reference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.onHero,
                ),
              ),
              background: _Header(
                location: booking.location,
                status: currentStatus,
                liveConnected: _liveUpdatesConnected,
              ),
            ),
          ),
          SliverPadding(
            padding: AppPageInsets.withSafeAreaBottom(
              context,
              AppPageInsets.standard,
            ),
            sliver: SliverList.list(
              children: [
                const _SectionTitle('Progress'),
                if (progress != null)
                  SurfaceCard(
                    child: Timeline(
                      steps: [
                        for (var i = 0; i < bookingProgressSteps.length; i++)
                          TimelineStep(
                            title: bookingProgressSteps[i],
                            state: i < progress || (finished && i == progress)
                                ? TimelineState.done
                                : i == progress
                                    ? TimelineState.current
                                    : TimelineState.upcoming,
                          ),
                      ],
                    ),
                  )
                else
                  _Notice(
                    icon: Icons.cancel_outlined,
                    text: currentStatus.toLowerCase() == 'rejected'
                        ? 'This booking was rejected.'
                        : 'This booking was cancelled.',
                    tone: colors.danger,
                  ),
                const SizedBox(height: AppSpace.xl),
                const _SectionTitle('Delivery location'),
                if (latitude != null && longitude != null) ...[
                  ClipRRect(
                    borderRadius: AppRadius.cardBorder,
                    child: SizedBox(
                      height: 180,
                      child: BrandMap(center: LatLng(latitude, longitude)),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],
                SurfaceCard(
                  child: _Rows([
                    AppListRow(
                      leading: const Icon(Icons.place_outlined),
                      title: booking.location,
                      subtitle: latitude != null && longitude != null
                          ? 'Coordinates: ${latitude.toStringAsFixed(5)}, '
                              '${longitude.toStringAsFixed(5)}'
                          : null,
                    ),
                    if (booking.notes != null &&
                        booking.notes!.trim().isNotEmpty)
                      AppListRow(
                        leading: const Icon(Icons.info_outline),
                        title: 'Access notes',
                        subtitle: booking.notes,
                      ),
                  ]),
                ),
                if (booking.cancellationReason != null &&
                    booking.cancellationReason!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpace.md),
                  _Notice(
                    icon: Icons.report_outlined,
                    text: 'Cancellation reason: ${booking.cancellationReason}',
                    tone: colors.warning,
                  ),
                ],
                const SizedBox(height: AppSpace.xl),
                _LiveTrackingSection(
                  tracking: tracking,
                  liveUpdatesError: _liveUpdatesError,
                  onRetry: _refreshTracking,
                ),
                const SizedBox(height: AppSpace.xl),
                const _SectionTitle('Order'),
                SurfaceCard(
                  child: _Rows([
                    for (final service in booking.services)
                      AppListRow(
                        leading: const Icon(Icons.local_shipping_outlined),
                        title: BookingServiceForm.forService(service.serviceId)
                            .serviceName,
                        subtitle: [
                          if (service.quantity.trim().isNotEmpty)
                            'Quantity/capacity: ${service.quantity}',
                          if (service.waterType?.trim().isNotEmpty == true)
                            'Water type: ${service.waterType}',
                          if (service.tankerCount?.trim().isNotEmpty == true)
                            'Tanker count: ${service.tankerCount}',
                          if (service.details.trim().isNotEmpty)
                            'Details: ${service.details}',
                        ].join('\n'),
                      ),
                    AppListRow(
                      leading: const Icon(Icons.water_drop_outlined),
                      title: 'Capacity',
                      subtitle: booking.capacity.isEmpty
                          ? 'Not specified'
                          : '${booking.capacity} litres',
                    ),
                    AppListRow(
                      leading: const Icon(Icons.event_outlined),
                      title: 'Delivery date',
                      subtitle: formatBookingDate(booking.deliveryDate),
                    ),
                    if (booking.quotedAmountRupees != null)
                      AppListRow(
                        leading: const Icon(Icons.currency_rupee_outlined),
                        title: 'Quoted amount',
                        trailing: AmountText(
                          '₹${booking.quotedAmountRupees!.toStringAsFixed(2)}',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    if (booking.paymentStatus != null &&
                        booking.paymentStatus!.isNotEmpty)
                      AppListRow(
                        leading: const Icon(Icons.payments_outlined),
                        title: 'Payment status',
                        subtitle: bookingPaymentLabel(
                          booking.normalizedPaymentStatus,
                        ),
                      ),
                    if (booking.normalizedPaymentStatus != 'cod')
                      _PaymentReceiptSection(
                        future: _receiptFuture,
                        showCheckAction: booking.normalizedPaymentStatus != 'paid',
                        onCheck: _refreshReceipt,
                      ),
                  ]),
                ),
                const SizedBox(height: AppSpace.xl),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    if (changesAllowed)
                      SecondaryButton(
                        label: 'Reschedule',
                        icon: Icons.event_repeat_outlined,
                        expand: false,
                        onPressed: () => _reschedule(context, ref),
                      ),
                    if (changesAllowed)
                      SecondaryButton(
                        label: 'Cancel',
                        icon: Icons.cancel_outlined,
                        expand: false,
                        onPressed: () => _cancel(context, ref),
                      ),
                  ],
                ),
                if (booking.normalizedPaymentStatus == 'cod' &&
                    _payOnlineStatuses.contains(currentStatus)) ...[
                  const SizedBox(height: AppSpace.md),
                  PrimaryButton(
                    label: _payingOnline ? 'Processing payment…' : 'Pay online now',
                    icon: Icons.credit_card_outlined,
                    onPressed: _payingOnline
                        ? null
                        : () => _payOnlineNow(context, ref),
                  ),
                ],
                if (currentStatus == 'arrived') ...[
                  const SizedBox(height: AppSpace.md),
                  PrimaryButton(
                    label: 'Request delivery OTP',
                    icon: Icons.password_outlined,
                    onPressed: () => _requestOtp(context, ref),
                  ),
                ],
                if (currentStatus == 'delivered') ...[
                  const SizedBox(height: AppSpace.md),
                  PrimaryButton(
                    label: 'Rate delivery',
                    icon: Icons.star_outline,
                    onPressed: () => _rate(context, ref),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _payOnlineNow(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(appControllerProvider);
    final flow = OnlinePaymentFlow(
      api: controller.api,
      checkout: RazorpayPaymentCheckout(),
    );
    final description = 'Booking ${booking.reference}';
    final email = controller.user?.email?.trim();
    setState(() => _payingOnline = true);

    var outcome = await flow.payAfterCodSwitch(
      bookingId: booking.id,
      name: 'Urban Tanker',
      description: description,
      email: email == null || email.isEmpty ? null : email,
    );
    while (true) {
      switch (outcome.status) {
        case OnlinePaymentStatus.paid:
          if (mounted) setState(() => _payingOnline = false);
          _onPaymentSettled();
          if (context.mounted) {
            showAppSnack(
              context,
              'Payment received. The vendor and driver have been told not to collect cash.',
            );
          }
          return;
        case OnlinePaymentStatus.verificationPending:
          final retry = context.mounted &&
              await showAppConfirmDialog(
                context,
                title: 'Payment confirmation pending',
                message: outcome.message ?? 'Please retry confirmation.',
                confirmLabel: 'Retry confirmation',
                cancelLabel: 'Later',
              );
          if (!retry || outcome.pendingSuccess == null) {
            if (mounted) setState(() => _payingOnline = false);
            _onPaymentSettled();
            return;
          }
          outcome = await flow.confirm(outcome.pendingSuccess!);
        case OnlinePaymentStatus.cancelled:
        case OnlinePaymentStatus.failed:
          final retry = context.mounted &&
              await showAppConfirmDialog(
                context,
                title: 'Payment not completed',
                message: outcome.message ??
                    'Your booking is still cash on delivery. You can try again.',
                confirmLabel: 'Try again',
                cancelLabel: 'Keep cash on delivery',
              );
          if (!retry) {
            if (mounted) setState(() => _payingOnline = false);
            _onPaymentSettled();
            return;
          }
          outcome = await flow.payAfterCodSwitch(
            bookingId: booking.id,
            name: 'Urban Tanker',
            description: description,
            email: email == null || email.isEmpty ? null : email,
          );
      }
    }
  }

  void _onPaymentSettled() {
    ref.invalidate(bookingsProvider);
    ref.invalidate(bookingTrackingProvider(widget.booking.id));
    _refreshReceipt();
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppConfirmDialog(
      context,
      title: 'Cancel booking?',
      message: 'This action is sent to the server and cannot be undone.',
      confirmLabel: 'Cancel booking',
      cancelLabel: 'Keep',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.cancelBooking(booking.id);
      ref.invalidate(bookingsProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          friendlyError(error),
          variant: AppSnackVariant.error,
        );
      }
    }
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected == null || !context.mounted) return;
    try {
      await ref.read(appControllerProvider).api.rescheduleBooking(
            booking.id,
            DateTime(selected.year, selected.month, selected.day, 9),
          );
      ref.invalidate(bookingsProvider);
      if (context.mounted) Navigator.pop(context);
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          friendlyError(error),
          variant: AppSnackVariant.error,
        );
      }
    }
  }

  Future<void> _requestOtp(BuildContext context, WidgetRef ref) async {
    try {
      final expiresAt = await ref
          .read(appControllerProvider)
          .api
          .requestDeliveryOtp(booking.id);
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AppDialog(
            title: 'Delivery OTP requested',
            message:
                'The OTP was sent to your registered mobile number and expires at ${expiresAt.toLocal()}.',
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Done'),
              ),
            ],
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          friendlyError(error),
          variant: AppSnackVariant.error,
        );
      }
    }
  }

  Future<void> _rate(BuildContext context, WidgetRef ref) async {
    var rating = 5;
    final review = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AppDialog(
          title: 'Rate delivery',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DropdownButton<int>(
                value: rating,
                items: [1, 2, 3, 4, 5]
                    .map(
                      (value) => DropdownMenuItem(
                        value: value,
                        child: Text('$value stars'),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => rating = value ?? 5),
              ),
              TextField(
                controller: review,
                decoration: const InputDecoration(
                  labelText: 'Review (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
    if (submitted != true || !context.mounted) {
      review.dispose();
      return;
    }
    try {
      await ref.read(appControllerProvider).api.rateBooking(
            booking.id,
            rating: rating,
            review: review.text.trim().isEmpty ? null : review.text.trim(),
          );
      if (context.mounted) {
        showAppSnack(
          context,
          'Thank you for rating the delivery.',
          variant: AppSnackVariant.success,
        );
      }
    } catch (error) {
      if (context.mounted) {
        showAppSnack(
          context,
          friendlyError(error),
          variant: AppSnackVariant.error,
        );
      }
    } finally {
      review.dispose();
    }
  }
}

/// Gradient header behind the collapsing app bar. Shows the status and the
/// delivery place.
/// Payment detail under the booking's payment status: amount, method and
/// paid time once Razorpay has captured the payment, plus a manual check for
/// online payments that are not yet confirmed (for example, when the app was
/// closed mid-checkout).
class _PaymentReceiptSection extends StatelessWidget {
  const _PaymentReceiptSection({
    required this.future,
    required this.showCheckAction,
    required this.onCheck,
  });

  final Future<PaymentReceipt?>? future;
  final bool showCheckAction;
  final VoidCallback onCheck;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PaymentReceipt?>(
      future: future,
      builder: (context, snapshot) {
        final receipt = snapshot.connectionState == ConnectionState.done
            ? snapshot.data
            : null;
        final paidAt = receipt?.capturedAt;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (receipt != null && receipt.isPaid) ...[
              AppListRow(
                leading: const Icon(Icons.receipt_long_outlined),
                title: 'Amount paid',
                trailing: AmountText(
                  _formatRupees(receipt.amountPaise / 100),
                ),
              ),
              AppListRow(
                leading: const Icon(Icons.credit_card_outlined),
                title: 'Paid via',
                subtitle: receipt.methodLabel,
              ),
              if (paidAt != null)
                AppListRow(
                  leading: const Icon(Icons.schedule_outlined),
                  title: 'Paid at',
                  subtitle: _formatPaidAt(paidAt),
                ),
            ],
            if (showCheckAction)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: SecondaryButton(
                  label: 'Check payment status',
                  icon: Icons.refresh_outlined,
                  expand: false,
                  onPressed: onCheck,
                ),
              ),
          ],
        );
      },
    );
  }
}

String _formatRupees(double value) => '₹${value.toStringAsFixed(2)}';

String _formatPaidAt(DateTime value) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}

class _Header extends StatelessWidget {
  const _Header({
    required this.location,
    required this.status,
    required this.liveConnected,
  });

  final String location;
  final String status;
  final bool liveConnected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: colors.heroGradient),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.xl,
          88,
          AppSpace.xl,
          64,
        ),
        child: Align(
          alignment: AlignmentDirectional.bottomStart,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(child: BookingStatusChip(status: status)),
                  const SizedBox(width: AppSpace.sm),
                  Text(
                    liveConnected ? 'Live' : 'Auto-refresh',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onHero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                location,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onHero,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiveTrackingSection extends StatelessWidget {
  const _LiveTrackingSection({
    required this.tracking,
    required this.liveUpdatesError,
    required this.onRetry,
  });

  final AsyncValue<TrackingSnapshot> tracking;
  final String? liveUpdatesError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Live tracking'),
        if (liveUpdatesError != null) ...[
          Text(
            'Live updates unavailable; checking periodically.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpace.sm),
        ],
        tracking.when(
          loading: () => const SkeletonBox(height: 88, radius: AppRadius.card),
          error: (error, _) => SurfaceCard(
            child: AppStateInline.error(
              error: error,
              message: 'Live tracking is temporarily unavailable.',
              onRetry: onRetry,
            ),
          ),
          data: (snapshot) => _TrackingCard(
            snapshot: snapshot,
            tone: snapshot.trackingAvailable ? colors.success : colors.neutral,
          ),
        ),
      ],
    );
  }
}

class _TrackingCard extends StatelessWidget {
  const _TrackingCard({required this.snapshot, required this.tone});

  final TrackingSnapshot snapshot;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: AppListRow(
        leading: Icon(
          snapshot.trackingAvailable
              ? Icons.location_on_outlined
              : Icons.location_searching_outlined,
          color: tone.fg,
        ),
        title: snapshot.trackingAvailable
            ? 'Vendor location available'
            : 'Waiting for vendor location',
        subtitle: [
          if (snapshot.driver != null) 'Driver: ${snapshot.driver}',
          if (snapshot.vehicle != null) 'Vehicle: ${snapshot.vehicle}',
          if (snapshot.latitude != null && snapshot.longitude != null)
            'Location: ${snapshot.latitude!.toStringAsFixed(5)}, '
                '${snapshot.longitude!.toStringAsFixed(5)}',
          if (snapshot.accuracy != null)
            'Accuracy: ${snapshot.accuracy!.round()} m',
          if (snapshot.recordedAt != null)
            'Updated: ${formatBookingDate(snapshot.recordedAt)}',
        ].join('\n'),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, required this.tone});

  final IconData icon;
  final String text;
  final AppTone tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: tone.border),
      ),
      child: Padding(
        padding: AppPageInsets.card,
        child: Row(
          children: [
            Icon(icon, color: tone.fg),
            const SizedBox(width: AppSpace.md),
            Expanded(
              child: Text(
                text,
                style: TextStyle(color: tone.fg, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rows separated by hairline dividers, inside a surface card.
class _Rows extends StatelessWidget {
  const _Rows(this.rows);

  final List<Widget> rows;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            rows[i],
          ],
        ],
      );
}
