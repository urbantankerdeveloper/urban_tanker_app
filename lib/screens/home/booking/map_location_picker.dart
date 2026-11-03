import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design_system/design_system.dart';
import '../../../services/service_area.dart';
import '../../common/brand_map.dart';
import '../../common/map_tiles.dart';

class MapLocationPicker extends StatefulWidget {
  const MapLocationPicker({super.key, this.latitude, this.longitude});

  final double? latitude;
  final double? longitude;

  @override
  State<MapLocationPicker> createState() => _MapLocationPickerState();
}

class _MapLocationPickerState extends State<MapLocationPicker> {
  static const _chennai = LatLng(13.0827, 80.2707);
  late LatLng _center;
  LatLng? _selected;

  @override
  void initState() {
    super.initState();
    _center = widget.latitude != null && widget.longitude != null
        ? LatLng(widget.latitude!, widget.longitude!)
        : _chennai;
    _selected =
        widget.latitude != null && widget.longitude != null ? _center : null;
  }

  @override
  Widget build(BuildContext context) => AppDialog(
        title: 'Choose delivery location',
        content: Semantics(
          label: 'Map to choose the delivery location',
          child: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: _center,
                initialZoom: 11,
                onTap: (_, point) {
                  if (!isChennaiLocation(
                    latitude: point.latitude,
                    longitude: point.longitude,
                  )) {
                    showAppSnack(context, 'Choose a location inside Chennai.');
                    return;
                  }
                  setState(() => _selected = point);
                },
              ),
              children: [
                const MapTileLayer(),
                if (_selected != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selected!,
                        width: 48,
                        height: 48,
                        child: BrandPin(
                          color: context.colors.primary,
                          foreground: context.colors.onHero,
                        ),
                      ),
                    ],
                  ),
                const MapAttribution(),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.pop(context, _selected),
            child: const Text('Use coordinates'),
          ),
        ],
      );
}
