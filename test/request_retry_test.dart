import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _SignedInApiClient extends ApiClient {
  _SignedInApiClient({required http.Client client})
      : super(client: client, baseUrl: 'https://example.test/api');

  @override
  Future<String?> readAccessToken() async => 'access-token';
}

void main() {
  test('GET requests retry on 503 and then succeed', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      if (calls == 1) return http.Response('unavailable', 503);
      return http.Response(jsonEncode({'ok': true}), 200);
    });

    final response =
        await _SignedInApiClient(client: client).request('GET', '/health');

    expect(response.statusCode, 200);
    expect(calls, 2);
  });

  test('write requests are never sent twice', () async {
    var calls = 0;
    final client = MockClient((_) async {
      calls++;
      return http.Response('unavailable', 503);
    });

    await expectLater(
      _SignedInApiClient(client: client).request(
        'POST',
        '/customer/orders',
        body: const {'service': 'water'},
      ),
      throwsA(isA<ApiException>()),
    );
    expect(calls, 1);
  });
}
