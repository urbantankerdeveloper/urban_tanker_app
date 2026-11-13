import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/design_system/design_system.dart';
import 'brand_map.dart';
import 'map_tiles.dart';

class OsmMapView extends StatefulWidget {
  const OsmMapView({
    required this.initialCenter,
    required this.vehicle,
    required this.destination,
    required this.accuracyMeters,
    required this.initialZoom,
    required this.interactive,
    required this.onTap,
    super.key,
  });

  final LatLng initialCenter;
  final LatLng? vehicle;
  final LatLng? destination;
  final double? accuracyMeters;
  final double initialZoom;
  final bool interactive;
  final ValueChanged<LatLng>? onTap;

  @override
  State<OsmMapView> createState() => _OsmMapViewState();
}

class _OsmMapViewState extends State<OsmMapView> {
  final _controller = MapController();
  bool _mapReady = false;
  bool _followVehicle = true;

  @override
  void didUpdateWidget(covariant OsmMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.vehicle != oldWidget.vehicle &&
        widget.vehicle != null &&
        _followVehicle) {
      if (_mapReady) _controller.move(widget.vehicle!, _controller.camera.zoom);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehicle = widget.vehicle;
    return Stack(
      fit: StackFit.expand,
      children: [
        Semantics(
          label: 'Map showing the vehicle location',
          child: FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: widget.initialZoom,
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
              onMapReady: () => _mapReady = true,
              onTap: widget.onTap == null
                  ? null
                  : (_, point) => widget.onTap!(point),
              onPositionChanged: (_, hasGesture) {
                if (hasGesture && _followVehicle) {
                  setState(() => _followVehicle = false);
                }
              },
            ),
            children: [
              const MapTileLayer(),
              if (vehicle != null &&
                  widget.accuracyMeters != null &&
                  widget.accuracyMeters!.isFinite &&
                  widget.accuracyMeters! > 0)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: vehicle,
                      radius: widget.accuracyMeters!.clamp(1, 2000).toDouble(),
                      useRadiusInMeter: true,
                      color: colors.primary.withValues(alpha: 0.12),
                      borderColor: colors.primary.withValues(alpha: 0.55),
                      borderStrokeWidth: 1.5,
                    ),
                  ],
                ),
              if (vehicle != null || widget.destination != null)
                MarkerLayer(
                  markers: [
                    if (widget.destination case final destination?)
                      Marker(
                        point: destination,
                        width: 48,
                        height: 48,
                        child: BrandPin(
                          color: const Color(0xFF2D5FC4),
                          foreground: colors.onHero,
                        ),
                      ),
                    if (vehicle case final point?)
                      Marker(
                        point: point,
                        width: 72,
                        height: 72,
                        child: const _VehicleMarker(),
                      ),
                  ],
                ),
              const MapAttribution(),
            ],
          ),
        ),
        if (vehicle != null && !_followVehicle)
          Positioned(
            top: AppSpace.xxxl + 64,
            right: AppSpace.xl,
            child: SafeArea(
              child: FloatingActionButton.small(
                heroTag: 'center-on-vehicle',
                tooltip: 'Center on vehicle',
                onPressed: () {
                  setState(() => _followVehicle = true);
                  _controller.move(vehicle, _controller.camera.zoom);
                },
                child: const Icon(Icons.my_location),
              ),
            ),
          ),
      ],
    );
  }
}

class _VehicleMarker extends StatefulWidget {
  const _VehicleMarker();

  @override
  State<_VehicleMarker> createState() => _VehicleMarkerState();
}

class _VehicleMarkerState extends State<_VehicleMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Stack(
      alignment: Alignment.center,
      children: [
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, _) => Container(
              width: 30 + 40 * _pulse.value,
              height: 30 + 40 * _pulse.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    colors.primary.withValues(alpha: 0.35 * (1 - _pulse.value)),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 40,
          height: 40,
          child: BrandPin(
            color: colors.primary,
            foreground: colors.onHero,
            icon: Icons.local_shipping,
          ),
        ),
      ],
    );
  }
}
