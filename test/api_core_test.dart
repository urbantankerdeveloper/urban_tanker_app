import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:urban_tanker_app/services/api_client.dart';

/// Keeps secure storage in memory so the tests run without platform channels.
class _MemoryStorage extends FlutterSecureStorage {
  final values = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      values[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    values.remove(key);
  }
}

ApiClient _apiFor(http.Client client, {_MemoryStorage? storage}) => ApiClient(
      client: client,
      storage: storage ?? _MemoryStorage(),
      baseUrl: 'https://example.test/api',
    );

/// Records each call made through [request] and returns an empty success.
class _RecordingApi extends ApiClient {
  _RecordingApi()
      : super(
          client: MockClient((_) async => http.Response('{}', 200)),
          storage: _MemoryStorage(),
          baseUrl: 'https://example.test/api',
        );

  final calls = <String>[];

  @override
  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    String contentType = 'application/json',
    bool retry = true,
  }) async {
    calls.add('$method $path');
    return http.Response('{}', 200);
  }
}

void main() {
  group('errors', () {
    test('the server message and field errors join into one message', () async {
      final api = _apiFor(
        MockClient(
          (_) async => http.Response(
            jsonEncode({
              'error': 'Invalid request',
              'details': {
                'fieldErrors': {
                  'phone': ['is too short'],
                  'name': ['is required'],
                },
              },
            }),
            400,
          ),
        ),
      );

      await expectLater(
        api.updateProfile(name: '', email: 'a@example.test'),
        throwsA(
          isA<ApiException>()
              .having(
                (error) => error.message,
                'message',
                'Invalid request: phone: is too short; name: is required',
              )
              .having((error) => error.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('an error body that is not JSON gives the status code message',
        () async {
      final api = _apiFor(
        MockClient((_) async => http.Response('<html>oops</html>', 500)),
      );

      await expectLater(
        api.services(),
        throwsA(
          isA<ApiException>()
              .having(
                  (error) => error.message, 'message', 'Request failed (500).')
              .having((error) => error.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('a success body that is not JSON hides the raw text', () async {
      final api = _apiFor(
        MockClient((_) async => http.Response('<html>secret</html>', 200)),
      );

      await expectLater(
        api.services(),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            'The server sent an unexpected response.',
          ),
        ),
      );
    });
  });

  group('retries', () {
    test('a GET retries after a dropped connection', () async {
      var calls = 0;
      final api = _apiFor(
        MockClient((_) async {
          calls++;
          if (calls == 1) throw const SocketException('connection reset');
          return http.Response('[]', 200);
        }),
      );

      expect(await api.services(), isEmpty);
      expect(calls, 2);
    });

    test('a write is not sent again after a dropped connection', () async {
      var calls = 0;
      final api = _apiFor(
        MockClient((_) async {
          calls++;
          throw const SocketException('connection reset');
        }),
      );

      await expectLater(
        api.updateThemePreference('dark'),
        throwsA(isA<SocketException>()),
      );
      expect(calls, 1);
    });
  });

  group('token refresh', () {
    test('a 401 refreshes the tokens and repeats the request once', () async {
      final storage = _MemoryStorage()
        ..values['urban_tanker_access_token'] = 'old-access'
        ..values['urban_tanker_refresh_token'] = 'old-refresh';
      final authHeaders = <String?>[];
      final api = _apiFor(
        MockClient((request) async {
          if (request.url.path == '/api/auth/mobile-refresh') {
            return http.Response(
              jsonEncode({
                'accessToken': 'new-access',
                'refreshToken': 'new-refresh',
              }),
              200,
            );
          }
          final header = request.headers['Authorization'];
          authHeaders.add(header);
          return header == 'Bearer new-access'
              ? http.Response('[]', 200)
              : http.Response('expired', 401);
        }),
        storage: storage,
      );

      expect(await api.services(), isEmpty);

      expect(authHeaders, ['Bearer old-access', 'Bearer new-access']);
      expect(storage.values['urban_tanker_access_token'], 'new-access');
      expect(storage.values['urban_tanker_refresh_token'], 'new-refresh');
    });

    test('a failed refresh clears the session and reports the 401', () async {
      final storage = _MemoryStorage()
        ..values['urban_tanker_access_token'] = 'old-access'
        ..values['urban_tanker_refresh_token'] = 'old-refresh';
      final api = _apiFor(
        MockClient((_) async => http.Response('expired', 401)),
        storage: storage,
      );

      await expectLater(
        api.services(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 401),
        ),
      );
      expect(storage.values, isEmpty);
    });

    test('a 401 without a refresh token is not retried', () async {
      var calls = 0;
      final storage = _MemoryStorage()
        ..values['urban_tanker_access_token'] = 'old-access';
      final api = _apiFor(
        MockClient((_) async {
          calls++;
          return http.Response('expired', 401);
        }),
        storage: storage,
      );

      await expectLater(api.services(), throwsA(isA<ApiException>()));
      expect(calls, 1);
    });
  });

  group('facade', () {
    test('endpoint calls go through the overridable request method', () async {
      final api = _RecordingApi();

      await api.updateThemePreference('dark');
      await api.logout('refresh-token-value');

      expect(api.calls, ['PATCH /auth/preferences', 'POST /auth/logout']);
    });

    test('a trailing slash is removed from the base URL', () {
      final api = ApiClient(
        client: MockClient((_) async => http.Response('{}', 200)),
        storage: _MemoryStorage(),
        baseUrl: 'https://example.test/api/',
      );

      expect(api.baseUrl, 'https://example.test/api');
    });
  });
}
