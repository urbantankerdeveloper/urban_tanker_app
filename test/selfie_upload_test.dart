import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:urban_tanker_app/services/api_client.dart';

class _RecordingApiClient extends ApiClient {
  _RecordingApiClient() : super(baseUrl: 'https://example.test/api');

  final List<
      ({
        String method,
        String path,
        List<int>? bodyBytes,
        String contentType,
      })> calls = [];

  @override
  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    String contentType = 'application/json',
    bool retry = true,
  }) async {
    calls.add((
      method: method,
      path: path,
      bodyBytes: bodyBytes,
      contentType: contentType,
    ));
    return http.Response('{"capturedAt":"2026-10-31T10:00:00.000Z"}', 201);
  }
}

void main() {
  final jpeg = [0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10];

  test('sends a JPEG selfie as the customer photo', () async {
    final client = _RecordingApiClient();

    await client.uploadCustomerSelfie(bytes: jpeg);

    expect(client.calls, hasLength(1));
    expect(client.calls.single.method, 'POST');
    expect(client.calls.single.path, '/customer/profile/selfie');
    expect(client.calls.single.contentType, 'image/jpeg');
    expect(client.calls.single.bodyBytes, jpeg);
  });

  test('rejects a non-JPEG photo before sending anything', () async {
    final client = _RecordingApiClient();

    await expectLater(
      client.uploadCustomerSelfie(bytes: [0x89, 0x50, 0x4e, 0x47]),
      throwsA(
        isA<FormatException>().having(
            (error) => error.message, 'message', 'Choose a JPEG photo.'),
      ),
    );
    expect(client.calls, isEmpty);
  });

  test('rejects a photo larger than 3 MB', () async {
    final client = _RecordingApiClient();
    final tooLarge = [0xff, 0xd8, 0xff, ...List.filled(3 * 1024 * 1024, 0)];

    await expectLater(
      client.uploadCustomerSelfie(bytes: tooLarge),
      throwsA(isA<FormatException>()),
    );
    expect(client.calls, isEmpty);
  });
}
