import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/design_system/design_system.dart';
import 'google_map_view.dart';
import 'last_updated_label.dart';
import 'map_provider_resolver.dart';
import 'osm_map_view.dart';

class LiveFleetMap extends StatelessWidget {
  const LiveFleetMap({
    required this.vehicle,
    required this.destination,
    required this.timeline,
    required this.lastUpdated,
    super.key,
    this.status,
    this.accuracyMeters,
    this.initialCenter,
    this.initialZoom = 15,
    this.interactive = true,
    this.onTap,
    this.resolver,
  });

  final LatLng? vehicle;
  final LatLng? destination;
  final List<String> timeline;
  final DateTime? lastUpdated;
  final String? status;
  final double? accuracyMeters;
  final LatLng? initialCenter;
  final double initialZoom;
  final bool interactive;
  final ValueChanged<LatLng>? onTap;
  final MapProviderResolver? resolver;

  @override
  Widget build(BuildContext context) {
    if (vehicle == null && destination == null && onTap == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: context.colors.softSurfaceGradient,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_shipping_outlined,
                size: 80,
                color: context.colors.primary.withValues(alpha: 0.35),
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                'Waiting for vehicle location',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    final mapResolver = resolver ?? MapProviderResolver.instance;
    final center = initialCenter ??
        vehicle ??
        destination ??
        const LatLng(13.0827, 80.2707);
    return Semantics(
      label: _contextLabel,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: mapResolver,
            builder: (context, _) {
              if (mapResolver.useGoogleMaps) {
                return GoogleMapView(
                  initialCenter: center,
                  vehicle: vehicle,
                  destination: destination,
                  accuracyMeters: accuracyMeters,
                  initialZoom: initialZoom,
                  interactive: interactive,
                  onTap: onTap,
                  resolver: mapResolver,
                );
              }
              return OsmMapView(
                initialCenter: center,
                vehicle: vehicle,
                destination: destination,
                accuracyMeters: accuracyMeters,
                initialZoom: initialZoom,
                interactive: interactive,
                onTap: onTap,
              );
            },
          ),
          if (lastUpdated != null)
            Positioned(
              top: AppSpace.xxxl + 64,
              left: AppSpace.xl,
              child: LastUpdatedLabel(lastUpdated: lastUpdated!),
            ),
        ],
      ),
    );
  }

  String get _contextLabel {
    final parts = <String>[
      'Map showing vehicle and delivery location',
      if (status != null && status!.isNotEmpty) 'Status: $status',
      if (timeline.isNotEmpty) 'Progress: ${timeline.join(', ')}',
      if (lastUpdated != null)
        'Last location update: ${lastUpdated!.toIso8601String()}',
    ];
    return parts.join('. ');
  }
}
