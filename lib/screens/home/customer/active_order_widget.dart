import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/auth_feature_flags.dart';
import '../../../app/providers.dart';
import '../../../core/design_system/design_system.dart';
import '../../../models/booking.dart';
import '../../../services/friendly_error.dart';
import '../../booking_details_screen.dart';
import '../../common/booking_format.dart';
import '../../common/live_fleet_map.dart';

/// Customer delivery summary displayed above the bottom navigation.
class ActiveOrderWidget extends ConsumerWidget {
  const ActiveOrderWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(bookingsProvider).value?.items;
    if (bookings == null) return const SizedBox.shrink();
    final active = bookings.where(isActiveBooking).firstOrNull;
    if (active == null) return const SizedBox.shrink();
    return _ActiveOrderPanel(key: ValueKey(active.id), booking: active);
  }
}

class _ActiveOrderPanel extends ConsumerStatefulWidget {
  const _ActiveOrderPanel({required this.booking, super.key});

  final Booking booking;

  @override
  ConsumerState<_ActiveOrderPanel> createState() => _ActiveOrderPanelState();
}

class _ActiveOrderPanelState extends ConsumerState<_ActiveOrderPanel> {
  bool _expanded = false;
  bool _requestingOtp = false;

  Booking get booking => widget.booking;

  @override
  Widget build(BuildContext context) {
    final tracking = _expanded
        ? ref.watch(bookingTrackingProvider(booking.id))
        : null;
    final snapshot = tracking?.value;
    final status = (snapshot?.status ?? booking.status).toLowerCase();
    final progress = bookingProgressIndex(status);
    final step = progress == null ? 0 : progress + 1;
    final scheduledFor = booking.deliveryDate;
    final multiService =
        AuthFeatureFlags.multiServiceOrders && booking.orderItems.isNotEmpty;
    final hasArrivedFulfilment = booking.fulfilments.any(
      (item) => item.status.toLowerCase() == 'arrived',
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.gutter,
        0,
        AppSpace.gutter,
        AppSpace.sm,
      ),
      child: Semantics(
        container: true,
        label: _expanded
            ? 'Active delivery ${booking.reference}, expanded'
            : 'Active delivery ${booking.reference}',
        child: _expanded
            ? _expandedCard(
                context,
                snapshot: snapshot,
                trackingError: tracking?.error,
                status: status,
                step: step,
                scheduledFor: scheduledFor,
                multiService: multiService,
                hasArrivedFulfilment: hasArrivedFulfilment,
              )
            : GradientCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.lg,
                  vertical: AppSpace.md,
                ),
                onTap: () => setState(() => _expanded = true),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking.reference,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: AppSpace.xs),
                          Text(
                            scheduledFor == null
                                ? StatusChip.statusLabel(status)
                                : 'Scheduled '
                                      '${_scheduleLabel(context, scheduledFor)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: AppSpace.sm),
                          LinearProgressIndicator(
                            value: step / bookingProgressSteps.length,
                            backgroundColor: context.colors.onHero.withValues(
                              alpha: 0.24,
                            ),
                            color: context.colors.onHero,
                            minHeight: AppSize.progressBarHeight,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.sm),
                    IconButton(
                      tooltip: 'Expand active delivery',
                      onPressed: () => setState(() => _expanded = true),
                      icon: const Icon(Icons.expand_less),
                      color: context.colors.onHero,
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _expandedCard(
    BuildContext context, {
    required TrackingSnapshot? snapshot,
    required Object? trackingError,
    required String status,
    required int step,
    required DateTime? scheduledFor,
    required bool multiService,
    required bool hasArrivedFulfilment,
  }) {
    final vehicle = _validPoint(snapshot?.latitude, snapshot?.longitude);
    final destination = _validPoint(booking.latitude, booking.longitude);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.5,
      ),
      child: SingleChildScrollView(
        child: SurfaceCard(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      booking.reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  BookingStatusChip(status: status),
                  IconButton(
                    tooltip: 'Collapse active delivery',
                    onPressed: () => setState(() => _expanded = false),
                    icon: const Icon(Icons.expand_more),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: AppRadius.cardBorder,
                child: SizedBox(
                  height: AppSize.activeOrderMapHeight,
                  child: LiveFleetMap(
                    vehicle: snapshot?.trackingAvailable == true
                        ? vehicle
                        : null,
                    destination: destination,
                    timeline: bookingProgressSteps.take(step).toList(),
                    lastUpdated: snapshot?.recordedAt,
                    status: status,
                    accuracyMeters: snapshot?.accuracy,
                    interactive: false,
                  ),
                ),
              ),
              if (trackingError != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  'Live location is temporarily unavailable: '
                  '${friendlyError(trackingError)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppSpace.sm),
              Text(
                scheduledFor == null
                    ? 'Delivery time not scheduled'
                    : 'Scheduled delivery: '
                          '${_scheduleLabel(context, scheduledFor)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text('Driver: ${snapshot?.driver ?? 'Not assigned'}'),
              Text('Vehicle: ${snapshot?.vehicle ?? 'Not assigned'}'),
              const SizedBox(height: AppSpace.sm),
              if (multiService && hasArrivedFulfilment)
                SecondaryButton(
                  label: 'View service delivery codes',
                  icon: Icons.password_outlined,
                  onPressed: () => _openDetails(context),
                )
              else if (!multiService && status == 'arrived')
                PrimaryButton(
                  label: _requestingOtp
                      ? 'Requesting code...'
                      : 'Get delivery OTP',
                  icon: Icons.password_outlined,
                  loading: _requestingOtp,
                  onPressed: _requestingOtp ? null : _requestOtp,
                ),
              const SizedBox(height: AppSpace.xs),
              SecondaryButton(
                label: 'Track live',
                icon: Icons.map_outlined,
                onPressed: () => _openDetails(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestOtp() async {
    setState(() => _requestingOtp = true);
    try {
      final result = await ref
          .read(appControllerProvider)
          .api
          .requestDeliveryOtp(booking.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AppDialog(
          title: 'Delivery OTP',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Booking ${booking.reference}'),
              const SizedBox(height: AppSpace.md),
              SelectableText(
                result.otp,
                textAlign: TextAlign.center,
                style: Theme.of(dialogContext).textTheme.headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 8),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                '${result.smsSent ? '' : 'SMS was not sent. '}'
                'Share this code with the vendor to confirm delivery. '
                'It expires at ${result.expiresAt.toLocal()}.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          'Could not request the delivery OTP: ${friendlyError(error)}',
          variant: AppSnackVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _requestingOtp = false);
    }
  }

  void _openDetails(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingDetailsScreen(booking: booking),
      ),
    );
  }

  static LatLng? _validPoint(double? latitude, double? longitude) {
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  static String _scheduleLabel(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final time = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(TimeOfDay.fromDateTime(local));
    return '${formatBookingDate(local)} $time';
  }
}
