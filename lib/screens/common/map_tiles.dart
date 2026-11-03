import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../core/design_system/design_system.dart';

/// Tiles for every map in the app. They come from CARTO's basemaps, which show
/// OpenStreetMap data in a light and a dark style, so the dark theme needs no
/// colour tint. Both styles need the attribution from [MapAttribution].
///
/// The host and style names are public and need no key. Check CARTO's current
/// terms and quota before launch. A keyed provider would need its key passed
/// at build time, never committed to source.
String mapTileUrl({required bool dark}) =>
    'https://{s}.basemaps.cartocdn.com/${dark ? 'dark_all' : 'light_all'}'
    '/{z}/{x}/{y}{r}.png';

const mapTileSubdomains = ['a', 'b', 'c', 'd'];

/// Identifies the app to the tile server. Keep it equal to the package name.
const mapUserAgent = 'com.urbantanker.app';

/// The tile layer for the current theme.
class MapTileLayer extends StatelessWidget {
  const MapTileLayer({super.key});

  @override
  Widget build(BuildContext context) => TileLayer(
        urlTemplate: mapTileUrl(dark: context.colors.isDark),
        subdomains: mapTileSubdomains,
        userAgentPackageName: mapUserAgent,
      );
}

/// Credits the data and the tile host. Both are required by the tile terms, so
/// every [FlutterMap] in the app includes this as a child layer.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) => RichAttributionWidget(
        showFlutterMapAttribution: false,
        attributions: const [
          TextSourceAttribution('OpenStreetMap contributors'),
          TextSourceAttribution('CARTO'),
        ],
      );
}
