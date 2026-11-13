import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart' as osm;

import '../../core/design_system/design_system.dart';
import 'map_coordinates.dart';
import 'map_provider_resolver.dart';

class GoogleMapView extends StatefulWidget {
  const GoogleMapView({
    required this.initialCenter,
    required this.vehicle,
    required this.destination,
    required this.accuracyMeters,
    required this.initialZoom,
    required this.interactive,
    required this.onTap,
    required this.resolver,
    super.key,
  });

  final osm.LatLng initialCenter;
  final osm.LatLng? vehicle;
  final osm.LatLng? destination;
  final double? accuracyMeters;
  final double initialZoom;
  final bool interactive;
  final ValueChanged<osm.LatLng>? onTap;
  final MapProviderResolver resolver;

  @override
  State<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView>
    with SingleTickerProviderStateMixin {
  static const _creationTimeout = Duration(seconds: 15);

  late final AnimationController _positionController;
  late final Timer _creationTimer;
  google.GoogleMapController? _mapController;
  google.BitmapDescriptor? _vehicleIcon;
  osm.LatLng? _displayedVehicle;
  LatLngTween? _positionTween;
  double _bearing = 0;
  bool _followVehicle = true;
  bool _programmaticCameraMove = false;
  bool _initialCameraFitDone = false;

  @override
  void initState() {
    super.initState();
    _displayedVehicle = widget.vehicle;
    _positionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..addListener(_updateAnimatedPosition);
    _creationTimer = Timer(_creationTimeout, () {
      if (_mapController == null) {
        debugPrint(
          'Google Maps did not initialize within '
          '${_creationTimeout.inSeconds} seconds; using OpenStreetMap.',
        );
        widget.resolver.markUnavailable();
      }
    });
    unawaited(_loadVehicleIcon());
  }

  @override
  void didUpdateWidget(covariant GoogleMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldVehicle = oldWidget.vehicle;
    final newVehicle = widget.vehicle;
    if (_samePoint(oldVehicle, newVehicle)) return;
    if (newVehicle == null) {
      _positionController.stop();
      _displayedVehicle = null;
      return;
    }
    if (oldVehicle == null) {
      setState(() => _displayedVehicle = newVehicle);
      if (_followVehicle) {
        if (widget.destination != null) {
          unawaited(_fitCameraToLocations());
        } else {
          unawaited(_moveCameraTo(newVehicle));
        }
      }
      return;
    }
    final start = _displayedVehicle ?? oldVehicle;
    _positionTween = LatLngTween(begin: start, end: newVehicle);
    _bearing = bearingBetween(start, newVehicle);
    _positionController.forward(from: 0);
    if (_followVehicle) _moveCameraTo(newVehicle);
  }

  @override
  void dispose() {
    _creationTimer.cancel();
    _positionController
      ..removeListener(_updateAnimatedPosition)
      ..dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadVehicleIcon() async {
    try {
      final icon = await _createVehicleIcon();
      if (mounted) setState(() => _vehicleIcon = icon);
    } on Exception catch (error, stackTrace) {
      debugPrint(
          'Could not create the vehicle map marker: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _vehicleIcon = google.BitmapDescriptor.defaultMarkerWithHue(
            google.BitmapDescriptor.hueOrange,
          );
        });
      }
    }
  }

  Future<google.BitmapDescriptor> _createVehicleIcon() async {
    const size = 96;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);
    canvas.drawCircle(
      center,
      44,
      Paint()..color = const Color(0xFF0D7770),
    );
    canvas.drawCircle(
      center,
      44,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.local_shipping.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontFamily: Icons.local_shipping.fontFamily,
          package: Icons.local_shipping.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(
        center.dx - painter.width / 2,
        center.dy - painter.height / 2,
      ),
    );
    final image = await recorder.endRecording().toImage(size, size);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError('Vehicle marker image encoding failed.');
    return google.BitmapDescriptor.bytes(
      data.buffer.asUint8List(),
      imagePixelRatio: 2,
    );
  }

  void _updateAnimatedPosition() {
    final tween = _positionTween;
    if (tween == null || !mounted) return;
    setState(() {
      _displayedVehicle = tween.transform(
        Curves.easeInOut.transform(_positionController.value),
      );
    });
  }

  void _onMapCreated(google.GoogleMapController controller) {
    _creationTimer.cancel();
    _mapController = controller;
    unawaited(_fitInitialCamera());
  }

  Future<void> _fitInitialCamera() async {
    if (_initialCameraFitDone) return;
    _initialCameraFitDone = true;
    final controller = _mapController;
    if (controller == null) return;

    await _fitCameraToLocations();
  }

  Future<void> _fitCameraToLocations() async {
    final controller = _mapController;
    if (controller == null) return;
    final vehicle = widget.vehicle;
    final destination = widget.destination;
    try {
      if (vehicle != null &&
          destination != null &&
          !_samePoint(vehicle, destination)) {
        final minLatitude = vehicle.latitude < destination.latitude
            ? vehicle.latitude
            : destination.latitude;
        final maxLatitude = vehicle.latitude > destination.latitude
            ? vehicle.latitude
            : destination.latitude;
        final minLongitude = vehicle.longitude < destination.longitude
            ? vehicle.longitude
            : destination.longitude;
        final maxLongitude = vehicle.longitude > destination.longitude
            ? vehicle.longitude
            : destination.longitude;
        final bounds = google.LatLngBounds(
          southwest: google.LatLng(minLatitude, minLongitude),
          northeast: google.LatLng(maxLatitude, maxLongitude),
        );
        await _animateCamera(
          google.CameraUpdate.newLatLngBounds(bounds, 64),
        );
      } else {
        final point = vehicle ?? destination ?? widget.initialCenter;
        await _animateCamera(
          google.CameraUpdate.newLatLngZoom(
            _toGoogle(point),
            widget.initialZoom,
          ),
        );
      }
    } on PlatformException catch (error, stackTrace) {
      _markUnavailable(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _markUnavailable(
        PlatformException(code: 'missing_plugin', message: error.message),
        stackTrace,
      );
    }
  }

  Future<void> _moveCameraTo(osm.LatLng point) async {
    try {
      await _animateCamera(google.CameraUpdate.newLatLng(_toGoogle(point)));
    } on PlatformException catch (error, stackTrace) {
      _markUnavailable(error, stackTrace);
    } on MissingPluginException catch (error, stackTrace) {
      _markUnavailable(
        PlatformException(code: 'missing_plugin', message: error.message),
        stackTrace,
      );
    }
  }

  Future<void> _animateCamera(google.CameraUpdate update) async {
    final controller = _mapController;
    if (controller == null) return;
    _programmaticCameraMove = true;
    try {
      await controller.animateCamera(update);
    } finally {
      _programmaticCameraMove = false;
    }
  }

  void _onCameraMoveStarted() {
    if (_programmaticCameraMove || !_initialCameraFitDone || !_followVehicle) {
      return;
    }
    setState(() => _followVehicle = false);
  }

  void _onCameraIdle() {
    _programmaticCameraMove = false;
  }

  void _recenter() {
    final vehicle = widget.vehicle;
    if (vehicle == null) return;
    setState(() => _followVehicle = true);
    unawaited(_moveCameraTo(vehicle));
  }

  void _markUnavailable(PlatformException error, StackTrace stackTrace) {
    debugPrint(
      'Google Maps platform error; using OpenStreetMap: $error\n$stackTrace',
    );
    widget.resolver.markUnavailable();
  }

  @override
  Widget build(BuildContext context) {
    final markers = <google.Marker>{};
    final vehicle = _displayedVehicle;
    if (vehicle != null) {
      markers.add(
        google.Marker(
          markerId: const google.MarkerId('vehicle'),
          position: _toGoogle(vehicle),
          icon: _vehicleIcon ??
              google.BitmapDescriptor.defaultMarkerWithHue(
                google.BitmapDescriptor.hueOrange,
              ),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: _bearing,
          infoWindow: const google.InfoWindow(title: 'Vehicle location'),
        ),
      );
    }
    if (widget.destination case final destination?) {
      markers.add(
        google.Marker(
          markerId: const google.MarkerId('destination'),
          position: _toGoogle(destination),
          icon: google.BitmapDescriptor.defaultMarkerWithHue(
            google.BitmapDescriptor.hueAzure,
          ),
          infoWindow: const google.InfoWindow(title: 'Delivery location'),
        ),
      );
    }
    final circles = <google.Circle>{};
    final accuracy = widget.accuracyMeters;
    if (vehicle != null &&
        accuracy != null &&
        accuracy.isFinite &&
        accuracy > 0) {
      circles.add(
        google.Circle(
          circleId: const google.CircleId('vehicle-accuracy'),
          center: _toGoogle(vehicle),
          radius: accuracy.clamp(1, 2000).toDouble(),
          fillColor: const Color(0x1F0D7770),
          strokeColor: const Color(0x8C0D7770),
          strokeWidth: 2,
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        google.GoogleMap(
          initialCameraPosition: google.CameraPosition(
            target: _toGoogle(widget.initialCenter),
            zoom: widget.initialZoom,
          ),
          markers: markers,
          circles: circles,
          onMapCreated: _onMapCreated,
          onCameraMoveStarted: _onCameraMoveStarted,
          onCameraIdle: _onCameraIdle,
          onTap: widget.onTap == null
              ? null
              : (point) => widget.onTap!(
                    osm.LatLng(point.latitude, point.longitude),
                  ),
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          compassEnabled: true,
          scrollGesturesEnabled: widget.interactive,
          zoomGesturesEnabled: widget.interactive,
          rotateGesturesEnabled: widget.interactive,
          tiltGesturesEnabled: widget.interactive,
        ),
        if (widget.vehicle != null && !_followVehicle)
          Positioned(
            top: AppSpace.xxxl + 64,
            right: 16,
            child: SafeArea(
              child: FloatingActionButton.small(
                heroTag: 'center-on-vehicle',
                tooltip: 'Center on vehicle',
                onPressed: _recenter,
                child: const Icon(Icons.my_location),
              ),
            ),
          ),
      ],
    );
  }
}

google.LatLng _toGoogle(osm.LatLng point) =>
    google.LatLng(point.latitude, point.longitude);

bool _samePoint(osm.LatLng? first, osm.LatLng? second) => first == null
    ? second == null
    : second != null &&
        first.latitude == second.latitude &&
        first.longitude == second.longitude;
