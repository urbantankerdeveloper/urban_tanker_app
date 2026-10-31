import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/tracking_link.dart';

void main() {
  const token = 'abcDEF123_-abcDEF123_-abcDEF123_-abcDEF123_-';

  test('reads the token from the app scheme', () {
    expect(
        trackingTokenFromUri(Uri.parse('urbantanker://track/$token')), token);
  });

  test('reads the token from a web tracking link', () {
    expect(
      trackingTokenFromUri(
          Uri.parse('https://urbantanker.example/track/$token')),
      token,
    );
  });

  test('rejects other paths and malformed tokens', () {
    expect(trackingTokenFromUri(Uri.parse('urbantanker://pay/$token')), isNull);
    expect(
        trackingTokenFromUri(Uri.parse('urbantanker://track/short')), isNull);
    expect(
      trackingTokenFromUri(
          Uri.parse('https://urbantanker.example/track/$token/extra')),
      isNull,
    );
  });
}
