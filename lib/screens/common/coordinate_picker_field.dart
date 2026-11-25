import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/design_system/design_system.dart';
import '../../services/friendly_error.dart';
import '../home/booking/map_location_picker.dart';

class CoordinatePickerField extends StatefulWidget {
  const CoordinatePickerField({
    super.key,
    required this.latitude,
    required this.longitude,
    this.label = 'Registered location (optional)',
  });

  final TextEditingController latitude;
  final TextEditingController longitude;
  final String label;

  @override
  State<CoordinatePickerField> createState() => _CoordinatePickerFieldState();
}

class _CoordinatePickerFieldState extends State<CoordinatePickerField> {
  bool _locating = false;

  bool get _hasLocation =>
      widget.latitude.text.trim().isNotEmpty &&
      widget.longitude.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpace.sm),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _chooseFromMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Choose from map'),
              ),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location_outlined),
                label: const Text('Use current location'),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  _hasLocation
                      ? 'Selected: ${widget.latitude.text}, ${widget.longitude.text}'
                      : 'No location selected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      );

  Future<void> _chooseFromMap() async {
    final latitude = double.tryParse(widget.latitude.text.trim());
    final longitude = double.tryParse(widget.longitude.text.trim());
    final coordinate = await showDialog<LatLng>(
      context: context,
      builder: (context) => MapLocationPicker(
        latitude: latitude,
        longitude: longitude,
        title: 'Choose registered location',
        restrictToChennai: false,
      ),
    );
    if (coordinate != null && mounted) {
      _setLocation(coordinate.latitude, coordinate.longitude);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (!mounted) return;
        await showAppPermissionDialog(
          context,
          message: 'Turn on location services to use your current location.',
          onOpenSettings: () {
            unawaited(Geolocator.openLocationSettings());
          },
        );
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        await showAppPermissionDialog(
          context,
          message:
              'Allow location access in device settings to use your current location.',
          onOpenSettings: () {
            unawaited(Geolocator.openAppSettings());
          },
        );
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          showAppSnack(
            context,
            'Location permission is needed to use your current location.',
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) _setLocation(position.latitude, position.longitude);
    } catch (error) {
      if (mounted) {
        showAppSnack(
          context,
          friendlyError(error),
          variant: AppSnackVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _setLocation(double latitude, double longitude) {
    widget.latitude.text = latitude.toString();
    widget.longitude.text = longitude.toString();
    setState(() {});
  }
}
