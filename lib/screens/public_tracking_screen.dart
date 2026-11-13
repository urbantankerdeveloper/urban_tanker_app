import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../core/design_system/design_system.dart';
import '../models/booking.dart';
import '../services/api_client.dart';
import '../services/friendly_error.dart';
import 'common/live_fleet_map.dart';

/// Public tracking for a booking, opened from a link. A map fills the screen
/// and a draggable sheet carries the details. The data refreshes every 30
/// seconds and when the app comes back to the foreground.
///
/// The share action is not here yet. Links use the `urbantanker://` scheme
/// until the public web host is configured, so a link shared today would not
/// open outside the app.
class PublicTrackingScreen extends StatefulWidget {
  const PublicTrackingScreen({
    required this.token,
    required this.api,
    super.key,
  });

  final String token;
  final ApiClient api;

  @override
  State<PublicTrackingScreen> createState() => _PublicTrackingScreenState();
}

class _PublicTrackingScreenState extends State<PublicTrackingScreen>
    with WidgetsBindingObserver {
  static const _pollInterval = Duration(seconds: 30);

  PublicTrackingSnapshot? _tracking;
  String? _error;
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh now, since the data may be old after time in the background.
      _startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) => _refresh());
    _refresh();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    // Only the first load shows a spinner. Later refreshes keep the last data.
    if (_tracking == null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final result = await widget.api.publicTracking(widget.token);
      if (mounted) {
        setState(() {
          _tracking = result;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = _tracking;
    if (tracking == null) {
      return AppScaffold(
        title: 'Track your booking',
        body: _error != null
            ? ErrorState(error: _error!, message: _error, onRetry: _refresh)
            : _loading
                ? const LoadingState(
                    message: 'Loading your tracking details...')
                : EmptyState(
                    icon: Icons.link_off_outlined,
                    title: 'Tracking link unavailable',
                    message: 'This tracking link is invalid or expired.',
                    action: SecondaryButton(
                      label: 'Refresh',
                      onPressed: _refresh,
                      expand: false,
                    ),
                  ),
      );
    }
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _MapArea(tracking: tracking),
          SafeArea(
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: AppPageInsets.card,
                child: _TopBar(reference: tracking.bookingReference),
              ),
            ),
          ),
          if (_error != null)
            SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 96),
                  child: _RefreshFailedPill(onRetry: _refresh),
                ),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.46,
            minChildSize: 0.26,
            maxChildSize: 0.92,
            snap: true,
            builder: (context, scrollController) => _Sheet(
              controller: scrollController,
              tracking: tracking,
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating glass bar over the map: back, and the booking reference.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.reference});

  final String reference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      radius: AppRadius.pillBorder,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.sm,
        vertical: AppSpace.xs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (Navigator.of(context).canPop())
            IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
            )
          else
            const SizedBox(width: AppSpace.md),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpace.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Track your booking', style: theme.textTheme.labelSmall),
                  Text(
                    reference,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshFailedPill extends StatelessWidget {
  const _RefreshFailedPill({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tone = context.colors.warning;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: AppRadius.pillBorder,
        border: Border.all(color: tone.border),
      ),
      child: Padding(
        padding: const EdgeInsets.only(
          left: AppSpace.lg,
          right: AppSpace.xs,
          top: AppSpace.xs,
          bottom: AppSpace.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                'Could not refresh. Showing the last update.',
                style: TextStyle(color: tone.fg, fontWeight: FontWeight.w600),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// The live map, or a branded placeholder until a vehicle fix arrives.
class _MapArea extends StatelessWidget {
  const _MapArea({required this.tracking});

  final PublicTrackingSnapshot tracking;

  static LatLng? _location(PublicTrackingSnapshot tracking) {
    final location = tracking.lastLocation;
    final latitude = location?.latitude;
    final longitude = location?.longitude;
    if (!tracking.trackingAvailable ||
        latitude == null ||
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

  static double? _accuracy(PublicTrackingSnapshot tracking) {
    final accuracy = tracking.lastLocation?.accuracy;
    if (accuracy == null || !accuracy.isFinite || accuracy <= 0) return null;
    return accuracy.clamp(1, 2000).toDouble();
  }

  @override
  Widget build(BuildContext context) => LiveFleetMap(
        vehicle: _location(tracking),
        destination: null,
        timeline: tracking.events.map((event) => event.status).toList(),
        status: tracking.status,
        lastUpdated: tracking.lastLocation?.recordedAt,
        accuracyMeters: _accuracy(tracking),
      );
}

/// Draggable bottom sheet: ETA, status, vehicle and driver, and the timeline.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.controller, required this.tracking});

  final ScrollController controller;
  final PublicTrackingSnapshot tracking;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final location = tracking.lastLocation;
    final hasVehicleLocation = _MapArea._location(tracking) != null;
    final events = tracking.events;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.sheetBorder,
        boxShadow: colors.shadowLifted,
      ),
      child: ListView(
        controller: controller,
        padding: AppPageInsets.withSafeAreaBottom(
          context,
          AppPageInsets.standard,
        ),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.hairline,
                borderRadius: AppRadius.pillBorder,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          Text('EXPECTED DELIVERY', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpace.xs),
          Text(
            _formatDateTime(tracking.expectedDelivery),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpace.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: BookingStatusChip(status: tracking.status),
          ),
          const SizedBox(height: AppSpace.lg),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                AppListRow(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: 'Vehicle',
                  subtitle: tracking.vehicle ?? 'Not assigned',
                ),
                const Divider(height: 1),
                AppListRow(
                  leading: tracking.driver == null
                      ? const Icon(Icons.person_outline)
                      : AppAvatar(name: tracking.driver!, size: 36),
                  title: 'Driver',
                  subtitle: tracking.driver ?? 'Not assigned',
                ),
                const Divider(height: 1),
                AppListRow(
                  leading: Icon(
                    hasVehicleLocation
                        ? Icons.location_on_outlined
                        : Icons.location_off_outlined,
                  ),
                  title: hasVehicleLocation
                      ? 'Vehicle location shared'
                      : 'Location not available yet',
                  subtitle: !hasVehicleLocation || location?.recordedAt == null
                      ? 'The latest vehicle location will appear here when shared.'
                      : 'Updated ${_formatDateTime(location!.recordedAt)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text('STATUS TIMELINE', style: theme.textTheme.labelSmall),
          const SizedBox(height: AppSpace.md),
          if (events.isEmpty)
            Text('No delivery events yet.', style: theme.textTheme.bodyMedium)
          else
            Timeline(
              steps: [
                for (var i = 0; i < events.length; i++)
                  TimelineStep(
                    title: events[i].status.replaceAll('_', ' '),
                    subtitle: [
                      if (events[i].note.isNotEmpty) events[i].note,
                      _formatDateTime(events[i].createdAt),
                    ].join('\n'),
                    state: i == events.length - 1
                        ? TimelineState.current
                        : TimelineState.done,
                  ),
              ],
            ),
          const SizedBox(height: AppSpace.lg),
          Text(
            'Refreshes every 30 seconds.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime? value) =>
    value == null ? 'Not available' : value.toLocal().toString();
