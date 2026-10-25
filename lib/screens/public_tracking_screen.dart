import 'dart:async';

import 'package:flutter/material.dart';

import '../models/booking.dart';
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
      body: _error != null
          ? _TrackingError(message: _error!, onRetry: _refresh)
          : _loading && tracking == null
              ? const Center(child: CircularProgressIndicator())
              : tracking == null
                  ? _TrackingError(
                      message: 'This tracking link is invalid or expired.',
                      onRetry: _refresh,
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
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
                              tracking.lastLocation == null)
                            const Card(
                              child: ListTile(
                                leading: Icon(Icons.location_off_outlined),
                                title: Text('Location not available yet'),
                                subtitle: Text(
                                  'The latest vehicle location will appear here when shared.',
                                ),
                              ),
                            )
                          else
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.location_on_outlined),
                                title: Text(
                                  '${tracking.lastLocation!.latitude}, '
                                  '${tracking.lastLocation!.longitude}',
                                ),
                                subtitle: Text(
                                  'Updated ${_formatDateTime(tracking.lastLocation!.recordedAt)}',
                                ),
                              ),
                            ),
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
                                  title: Text(
                                      event.status.replaceAll('_', ' ')),
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

class _TrackingError extends StatelessWidget {
  const _TrackingError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: const Text('Refresh')),
            ],
          ),
        ),
      );
}

String _formatDateTime(DateTime? value) =>
    value == null ? 'Not available' : value.toLocal().toString();
