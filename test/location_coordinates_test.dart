import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/location_coordinates.dart';

void main() {
  test('empty coordinate fields are omitted', () {
    expect(parseOptionalCoordinates('', ''), isEmpty);
  });

  test('valid latitude and longitude are parsed together', () {
    expect(parseOptionalCoordinates('-90', '180'), {
      'latitude': -90.0,
      'longitude': 180.0,
    });
  });

  test('partial and out-of-range coordinates are rejected', () {
    expect(
      () => parseOptionalCoordinates('13.0827', ''),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseOptionalCoordinates('90.1', '80'),
      throwsA(isA<FormatException>()),
    );
  });
}
