import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:latlong2/latlong.dart';

class LatLngTween extends Tween<LatLng> {
  LatLngTween({required LatLng begin, required LatLng end})
      : super(begin: begin, end: end);

  @override
  LatLng lerp(double t) {
    final start = begin!;
    final finish = end!;
    return LatLng(
      start.latitude + (finish.latitude - start.latitude) * t,
      start.longitude + (finish.longitude - start.longitude) * t,
    );
  }
}

double bearingBetween(LatLng from, LatLng to) {
  final latitude1 = _radians(from.latitude);
  final latitude2 = _radians(to.latitude);
  final longitudeDelta = _radians(to.longitude - from.longitude);
  final y = math.sin(longitudeDelta) * math.cos(latitude2);
  final x = math.cos(latitude1) * math.sin(latitude2) -
      math.sin(latitude1) * math.cos(latitude2) * math.cos(longitudeDelta);
  return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
}

double _radians(double degrees) => degrees * math.pi / 180;
