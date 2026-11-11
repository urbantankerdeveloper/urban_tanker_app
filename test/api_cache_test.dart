import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_tanker_app/services/api/api_core.dart';

ApiCore _core(
  http.Client client, {
  Duration ttl = const Duration(seconds: 90),
  DateTime Function()? clock,
}) =>
    ApiCore(
      client: client,
      storage: const FlutterSecureStorage(),
      baseUrl: 'https://example.test/api',
      tokenReader: () async => null,
      readCacheTtl: ttl,
      clock: clock,
    );

void main() {
  test('read-mostly GET responses are reused until TTL expiry', () async {
    var calls = 0;
    var now = DateTime.utc(2026);
    final api = _core(
      MockClient((_) async {
        calls++;
        return http.Response(jsonEncode({'version': calls}), 200);
      }),
      ttl: const Duration(seconds: 60),
      clock: () => now,
    );

    final first = await api.request('GET', '/customer/offers');
    final withinTtl = await api.request('GET', '/customer/offers');
    expect(identical(first, withinTtl), isTrue);
    expect(jsonDecode(withinTtl.body)['version'], 1);
    expect(calls, 1);

    now = now.add(const Duration(seconds: 61));
    final afterExpiry = await api.request('GET', '/customer/offers');
    expect(jsonDecode(afterExpiry.body)['version'], 2);
    expect(calls, 2);
  });

  test('cache keys include query parameters', () async {
    var calls = 0;
    final api = _core(
      MockClient((request) async {
        calls++;
        return http.Response(request.url.queryParameters['region']!, 200);
      }),
    );

    final east = await api.request(
      'GET',
      '/customer/services?region=east',
    );
    final west = await api.request(
      'GET',
      '/customer/services?region=west',
    );

    expect(east.body, 'east');
    expect(west.body, 'west');
    expect(calls, 2);

    api.invalidateReadCache(path: '/customer/services');
    await api.request('GET', '/customer/services?region=east');
    expect(calls, 3);
  });

  test('manual invalidation bypasses a valid cached response', () async {
    var calls = 0;
    final api = _core(
      MockClient((_) async => http.Response('${++calls}', 200)),
    );

    expect((await api.request('GET', '/customer/services')).body, '1');
    api.invalidateReadCache(path: '/customer/services');
    expect((await api.request('GET', '/customer/services')).body, '2');
    expect(calls, 2);
  });

  test('identical in-flight GETs share one network request', () async {
    var calls = 0;
    final response = Completer<http.Response>();
    final api = _core(
      MockClient((_) {
        calls++;
        return response.future;
      }),
    );

    final first = api.request('GET', '/customer/services');
    final second = api.request('GET', '/customer/services');
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(calls, 1);

    response.complete(http.Response('[]', 200));
    await Future.wait([first, second]);
    expect(calls, 1);
  });

  test('other GETs are not cached', () async {
    var calls = 0;
    final api = _core(
      MockClient((_) async => http.Response('${++calls}', 200)),
    );

    await api.request('GET', '/customer/profile');
    await api.request('GET', '/customer/profile');

    expect(calls, 2);
  });
}
