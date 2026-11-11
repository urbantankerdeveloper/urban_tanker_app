import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_tanker_app/services/api/api_core.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _SignedInApiClient extends ApiClient {
  _SignedInApiClient({required http.Client client})
      : super(client: client, baseUrl: 'https://example.test/api');

  @override
  Future<String?> readAccessToken() async => 'access-token';
}

ApiCore _core(
  http.Client client, {
  Duration getTimeout = const Duration(milliseconds: 40),
  Duration requestTimeout = const Duration(milliseconds: 120),
  Duration getRetryBudget = const Duration(milliseconds: 90),
  List<Duration> retryDelays = const [
    Duration(milliseconds: 10),
    Duration(milliseconds: 10),
  ],
}) =>
    ApiCore(
      client: client,
      storage: const FlutterSecureStorage(),
      baseUrl: 'https://example.test/api',
      tokenReader: () async => null,
      getTimeout: getTimeout,
      requestTimeout: requestTimeout,
      getRetryBudget: getRetryBudget,
      retryDelays: retryDelays,
    );

class _ApiCoreWithRefreshToken extends ApiCore {
  _ApiCoreWithRefreshToken(http.Client client)
      : super(
          client: client,
          storage: const FlutterSecureStorage(),
          baseUrl: 'https://example.test/api',
          tokenReader: () async => null,
          getTimeout: const Duration(milliseconds: 40),
          requestTimeout: const Duration(milliseconds: 120),
          getRetryBudget: const Duration(milliseconds: 90),
          retryDelays: const [
            Duration(milliseconds: 10),
            Duration(milliseconds: 10),
          ],
        );

  @override
  Future<String?> readRefreshToken() async => 'refresh-token';

  @override
  Future<void> clearTokens() async {}
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

  test('GET retries only the configured gateway statuses twice', () async {
    var calls = 0;
    final api = _core(
      MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('bad gateway', 502);
        if (calls == 2) return http.Response('gateway timeout', 504);
        return http.Response('[]', 200);
      }),
      retryDelays: const [Duration.zero, Duration.zero],
    );

    final response = await api.request('GET', '/health');

    expect(response.statusCode, 200);
    expect(calls, 3);
  });

  test('GET does not retry statuses outside the gateway set', () async {
    var calls = 0;
    final api = _core(
      MockClient((_) async {
        calls++;
        return http.Response('server error', 500);
      }),
    );

    await expectLater(
      api.request('GET', '/health'),
      throwsA(isA<ApiException>()),
    );

    expect(calls, 1);
  });

  test('GET retries stop within the total timeout budget', () async {
    var calls = 0;
    final api = _core(
      MockClient((_) {
        calls++;
        return Completer<http.Response>().future;
      }),
      getTimeout: const Duration(milliseconds: 40),
      getRetryBudget: const Duration(milliseconds: 90),
      retryDelays: const [
        Duration(milliseconds: 10),
        Duration(milliseconds: 10),
      ],
    );
    final stopwatch = Stopwatch()..start();

    await expectLater(
      api.request('GET', '/health'),
      throwsA(isA<TimeoutException>()),
    );

    expect(calls, 2);
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 300)));
  });

  test('GET authorization refresh stays inside the retry timeout budget',
      () async {
    var calls = 0;
    final api = _ApiCoreWithRefreshToken(
      MockClient((request) {
        calls++;
        if (request.method == 'GET') {
          return Future.value(http.Response('unauthorized', 401));
        }
        return Completer<http.Response>().future;
      }),
    );
    final stopwatch = Stopwatch()..start();

    await expectLater(
      api.request('GET', '/health'),
      throwsA(isA<TimeoutException>()),
    );

    expect(calls, 2);
    expect(stopwatch.elapsed, lessThan(const Duration(milliseconds: 300)));
  });

  test('booking writes and uploads retain longer timeout ceilings', () async {
    final methods = <String>[];
    final api = _core(
      MockClient((request) async {
        methods.add(request.method);
        await Future<void>.delayed(const Duration(milliseconds: 70));
        return http.Response('{}', 200);
      }),
      getTimeout: const Duration(milliseconds: 25),
      requestTimeout: const Duration(milliseconds: 100),
      getRetryBudget: const Duration(milliseconds: 40),
      retryDelays: const [Duration(milliseconds: 5)],
    );

    final bookingResponse = await api.request(
      'POST',
      '/customer/orders',
      body: const {'service': 'water'},
    );
    final uploadResponse = await api.sendRequest(
      http.Request('PUT', Uri.parse('https://uploads.example.test/file')),
    );

    expect(bookingResponse.statusCode, 200);
    expect(uploadResponse.statusCode, 200);
    expect(methods, ['POST', 'PUT']);
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
