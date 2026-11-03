import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/design_system/design_system.dart';
import 'map_tiles.dart';

/// Map view with a branded pin. Tiles follow the theme, see [MapTileLayer].
class BrandMap extends StatelessWidget {
  const BrandMap({
    required this.center,
    super.key,
    this.zoom = 15,
    this.interactive = false,
  });

  final LatLng center;
  final double zoom;

  /// Pan and zoom are off by default, so the map can sit inside a scrolling page.
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        const MapTileLayer(),
        MarkerLayer(
          markers: [
            Marker(
              point: center,
              width: 44,
              height: 44,
              child: BrandPin(color: colors.primary, foreground: colors.onHero),
            ),
          ],
        ),
        const MapAttribution(),
      ],
    );
  }
}

/// Round map pin with a soft shadow. Used for every marker, so the map looks
/// the same on each screen.
class BrandPin extends StatelessWidget {
  const BrandPin({
    required this.color,
    required this.foreground,
    super.key,
    this.icon = Icons.location_on,
  });

  final Color color;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: foreground, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: foreground, size: 22),
    );
  }
}
