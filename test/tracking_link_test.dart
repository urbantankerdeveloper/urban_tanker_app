import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/tracking_link.dart';

void main() {
  const token = 'abcDEF123_-abcDEF123_-abcDEF123_-abcDEF123_-';
  const webHosts = {'urbantanker.example'};

  test('reads the token from the app scheme', () {
    expect(
        trackingTokenFromUri(Uri.parse('urbantanker://track/$token')), token);
  });

  test('reads the token from an allow-listed https tracking link', () {
    expect(
      trackingTokenFromUri(
        Uri.parse('https://urbantanker.example/track/$token'),
        webHosts: webHosts,
      ),
      token,
    );
  });

  test('rejects https links from hosts that are not allow-listed', () {
    expect(
      trackingTokenFromUri(
        Uri.parse('https://evil.example/track/$token'),
        webHosts: webHosts,
      ),
      isNull,
    );
    expect(
      trackingTokenFromUri(
          Uri.parse('https://urbantanker.example/track/$token')),
      isNull,
    );
  });

  test('rejects non-https web links and other schemes', () {
    expect(
      trackingTokenFromUri(
        Uri.parse('http://urbantanker.example/track/$token'),
        webHosts: webHosts,
      ),
      isNull,
    );
    expect(
      trackingTokenFromUri(
        Uri.parse('intent://urbantanker.example/track/$token'),
        webHosts: webHosts,
      ),
      isNull,
    );
  });

  test('rejects other paths and malformed tokens', () {
    expect(trackingTokenFromUri(Uri.parse('urbantanker://pay/$token')), isNull);
    expect(
        trackingTokenFromUri(Uri.parse('urbantanker://track/short')), isNull);
    expect(
      trackingTokenFromUri(
        Uri.parse('https://urbantanker.example/track/$token/extra'),
        webHosts: webHosts,
      ),
      isNull,
    );
  });
}
