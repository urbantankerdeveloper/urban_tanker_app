import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/design_system/design_system.dart';

/// OpenStreetMap view with a branded pin. In dark mode the tiles get a dark
/// tint so they match the theme.
///
/// The tiles come from the public OSM tile server. It has usage limits and is
/// not meant for production traffic, so a commercial tile provider should be
/// chosen before launch. The provider has not been switched yet.
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

  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final map = FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: _tileUrl,
          userAgentPackageName: 'com.urbantanker.app',
        ),
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
      ],
    );
    if (!colors.isDark) return map;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        colors.scaffold.withValues(alpha: 0.55),
        BlendMode.multiply,
      ),
      child: map,
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
