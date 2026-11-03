import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

/// Every file LottieOrIcon can load must parse. A broken file would otherwise
/// fall back silently to the icon, so this test is the only signal.
void main() {
  const names = [
    'success',
    'empty',
    'error',
    'loading_water',
    'delivery_truck',
    'location_pin',
  ];

  for (final name in names) {
    test('$name.json parses as a 200 x 200 Lottie animation', () async {
      final bytes = await File('assets/lottie/$name.json').readAsBytes();
      final composition = await LottieComposition.fromBytes(bytes);

      expect(composition.bounds.width, 200);
      expect(composition.bounds.height, 200);
      expect(composition.durationFrames, greaterThan(0));
    });
  }
}
