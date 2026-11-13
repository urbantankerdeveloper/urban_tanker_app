import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/design_system/design_system.dart';
import '../../../services/service_area.dart';
import '../../common/live_fleet_map.dart';

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
            child: LiveFleetMap(
              vehicle: null,
              destination: _selected,
              timeline: const [],
              lastUpdated: null,
              initialCenter: _center,
              initialZoom: _selected == null ? 11 : 16,
              onTap: _selectLocation,
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

  void _selectLocation(LatLng point) {
    if (!isChennaiLocation(
      latitude: point.latitude,
      longitude: point.longitude,
    )) {
      showAppSnack(context, 'Choose a location inside Chennai.');
      return;
    }
    setState(() => _selected = point);
  }
}
