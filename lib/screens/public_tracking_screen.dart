import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/booking.dart';
import '../app/page_components.dart';
import '../services/api_client.dart';

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

class _PublicTrackingScreenState extends State<PublicTrackingScreen> {
  PublicTrackingSnapshot? _tracking;
  String? _error;
  Timer? _timer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.publicTracking(widget.token);
      if (mounted) setState(() => _tracking = result);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = _tracking;
    return Scaffold(
      appBar: AppBar(title: const Text('Track your booking')),
      body: _error != null && tracking == null
          ? AppStateView.error(error: _error!, onRetry: _refresh)
          : _loading && tracking == null
              ? const AppStateView.loading(message: 'Loading your tracking details...')
              : tracking == null
                  ? AppStateView.empty(
                      icon: Icons.link_off_outlined,
                      title: 'Tracking link unavailable',
                      message: 'This tracking link is invalid or expired.',
                      action: OutlinedButton(
                        onPressed: _refresh,
                        child: const Text('Refresh'),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        padding: AppPageInsets.standard,
                        children: [
                          if (_error != null)
                            AppStateInline.error(
                              error: _error!,
                              message:
                                  'Could not refresh tracking. Showing the last available update.',
                              onRetry: _refresh,
                            ),
                          Text(
                            tracking.bookingReference,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _TrackingField(
                            label: 'Current status',
                            value: tracking.status.replaceAll('_', ' '),
                          ),
                          _TrackingField(
                            label: 'Expected delivery',
                            value: _formatDateTime(tracking.expectedDelivery),
                          ),
                          _TrackingField(
                            label: 'Vehicle',
                            value: tracking.vehicle ?? 'Not assigned',
                          ),
                          _TrackingField(
                            label: 'Driver',
                            value: tracking.driver ?? 'Not assigned',
                          ),
                          const SizedBox(height: 16),
                          Text('Vehicle location',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (!tracking.trackingAvailable ||
                              tracking.lastLocation?.latitude == null ||
                              tracking.lastLocation?.longitude == null)
                            const Card(
                              child: ListTile(
                                leading: Icon(Icons.location_off_outlined),
                                title: Text('Location not available yet'),
                                subtitle: Text(
                                  'The latest vehicle location will appear here when shared.',
                                ),
                              ),
                            )
                          else ...[
                            _VehicleMap(
                              latitude: tracking.lastLocation!.latitude!,
                              longitude: tracking.lastLocation!.longitude!,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Updated ${_formatDateTime(tracking.lastLocation!.recordedAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text('Status timeline',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          if (tracking.events.isEmpty)
                            const Card(
                              child: ListTile(
                                title: Text('No delivery events yet.'),
                              ),
                            )
                          else
                            ...tracking.events.map(
                              (event) => Card(
                                child: ListTile(
                                  leading: const Icon(Icons.timeline),
                                  title:
                                      Text(event.status.replaceAll('_', ' ')),
                                  subtitle: Text([
                                    if (event.note.isNotEmpty) event.note,
                                    _formatDateTime(event.createdAt),
                                  ].join('\n')),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}

class _TrackingField extends StatelessWidget {
  const _TrackingField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 6),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      );
}

class _VehicleMap extends StatefulWidget {
  const _VehicleMap({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  @override
  State<_VehicleMap> createState() => _VehicleMapState();
}

class _VehicleMapState extends State<_VehicleMap> {
  final _controller = MapController();

  @override
  void didUpdateWidget(covariant _VehicleMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _controller.move(LatLng(widget.latitude, widget.longitude), 15);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = LatLng(widget.latitude, widget.longitude);
    return SizedBox(
      height: 260,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(initialCenter: vehicle, initialZoom: 15),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.urbantanker.app',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: vehicle,
                  width: 44,
                  height: 44,
                  child: Icon(
                    Icons.local_shipping,
                    color: Theme.of(context).colorScheme.primary,
                    size: 36,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDateTime(DateTime? value) =>
    value == null ? 'Not available' : value.toLocal().toString();
