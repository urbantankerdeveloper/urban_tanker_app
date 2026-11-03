import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_decode.dart';
import 'api_types.dart';

/// The HTTP layer every endpoint shares: the bearer token, one token refresh at
/// a time, GET-only retries, the slow-server flag and error messages.
class ApiCore {
  ApiCore({
    required http.Client client,
    required FlutterSecureStorage storage,
    required this.baseUrl,
    required Future<String?> Function() tokenReader,
  })  : _client = client,
        _storage = storage,
        _tokenReader = tokenReader;

  static const _slowRequestAfter = Duration(seconds: 3);
  static const _retryDelays = [
    Duration(milliseconds: 500),
    Duration(seconds: 1),
    Duration(seconds: 2),
  ];
  static const _retryableStatusCodes = {502, 503, 504};

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final Future<String?> Function() _tokenReader;
  final String baseUrl;
  Future<String?>? _refreshOperation;

  /// True while a request has taken longer than 3 seconds. The UI uses it to
  /// show that the server is waking up.
  final ValueNotifier<bool> slowRequest = ValueNotifier<bool>(false);
  int _slowRequestCount = 0;

  Future<void> saveAccessToken(String token) => _storage.write(
        key: 'urban_tanker_access_token',
        value: token,
      );

  Future<void> saveRefreshToken(String token) => _storage.write(
        key: 'urban_tanker_refresh_token',
        value: token,
      );

  Future<void> clearTokens() async {
    await _storage.delete(key: 'urban_tanker_access_token');
    await _storage.delete(key: 'urban_tanker_refresh_token');
  }

  /// Keeps the signed-in user profile in secure storage, not SharedPreferences.
  Future<void> saveSessionUser(Map<String, dynamic> user) => _storage.write(
        key: 'urban_tanker_session_user',
        value: jsonEncode(user),
      );

  Future<Map<String, dynamic>?> readSessionUser() async {
    final raw = await _storage.read(key: 'urban_tanker_session_user');
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  /// Removes the tokens and the stored user profile.
  Future<void> clearSession() async {
    await clearTokens();
    await _storage.delete(key: 'urban_tanker_session_user');
  }

  Future<String?> readAccessToken() =>
      _storage.read(key: 'urban_tanker_access_token');

  Future<String?> readRefreshToken() =>
      _storage.read(key: 'urban_tanker_refresh_token');

  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    String contentType = 'application/json',
    bool retry = true,
  }) =>
      _trackSlowRequest(
        _requestOnce(
          method,
          path,
          body: body,
          bodyBytes: bodyBytes,
          contentType: contentType,
          retry: retry,
        ),
      );

  Future<http.Response> sendRequest(
    http.BaseRequest request, {
    Duration timeout = const Duration(seconds: 20),
  }) =>
      _client.send(request).then(http.Response.fromStream).timeout(timeout);

  Future<T> _trackSlowRequest<T>(Future<T> operation) {
    var slow = false;
    final timer = Timer(_slowRequestAfter, () {
      slow = true;
      _slowRequestCount++;
      slowRequest.value = true;
    });
    return operation.whenComplete(() {
      timer.cancel();
      if (slow) {
        _slowRequestCount--;
        slowRequest.value = _slowRequestCount > 0;
      }
    });
  }

  Future<http.Response> _requestOnce(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    String contentType = 'application/json',
    bool retry = true,
  }) async {
    final response = await _sendWithRetries(
      method,
      path,
      body: body,
      bodyBytes: bodyBytes,
      contentType: contentType,
    );

    if (response.statusCode == 401 && retry && path != '/auth/mobile-refresh') {
      final newToken = await _refreshAccessToken();
      if (newToken != null) {
        return _requestOnce(
          method,
          path,
          body: body,
          bodyBytes: bodyBytes,
          contentType: contentType,
          retry: false,
        );
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = ApiException.genericFailureMessage(response.statusCode);
      try {
        final decoded = decodeBody(response);
        if (decoded is Map<String, dynamic>) {
          if (decoded['error'] is String) {
            message = decoded['error'] as String;
          }
          final details = decoded['details'];
          if (details is Map<String, dynamic>) {
            final fieldErrors = details['fieldErrors'];
            if (fieldErrors is Map<String, dynamic>) {
              final messages = <String>[];
              for (final entry in fieldErrors.entries) {
                if (entry.value is List) {
                  messages.addAll(
                    (entry.value as List)
                        .whereType<String>()
                        .map((detail) => '${entry.key}: $detail'),
                  );
                }
              }
              if (messages.isNotEmpty) {
                message = '$message: ${messages.join('; ')}';
              }
            }
          }
        }
      } on FormatException {
        // The status code remains the useful error when the body is not JSON.
      }
      throw ApiException(message, response.statusCode);
    }
    return response;
  }

  /// Sends the request. Only GET requests are retried, after timeouts, network
  /// errors and 502/503/504 responses. Writes are never sent twice.
  Future<http.Response> _sendWithRetries(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    required String contentType,
  }) async {
    for (var attempt = 0;; attempt++) {
      final canRetry = method == 'GET' && attempt < _retryDelays.length;
      try {
        final response = await _sendOnce(
          method,
          path,
          body: body,
          bodyBytes: bodyBytes,
          contentType: contentType,
        );
        if (!canRetry || !_retryableStatusCodes.contains(response.statusCode)) {
          return response;
        }
      } catch (error) {
        if (!canRetry || !_isNetworkFailure(error)) rethrow;
      }
      await Future<void>.delayed(_retryDelays[attempt]);
    }
  }

  bool _isNetworkFailure(Object error) =>
      error is TimeoutException || error is SocketException;

  Future<http.Response> _sendOnce(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    required String contentType,
  }) async {
    final token = await _tokenReader();
    final headers = <String, String>{
      'Content-Type': contentType,
      'X-Client-Platform': 'mobile',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final httpRequest = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(headers);
    if (bodyBytes != null) {
      httpRequest.bodyBytes = bodyBytes;
    } else {
      httpRequest.body = body == null ? '' : jsonEncode(body);
    }
    return sendRequest(httpRequest);
  }

  Future<String?> _refreshAccessToken() {
    final active = _refreshOperation;
    if (active != null) return active;
    final operation = _performRefresh();
    _refreshOperation = operation;
    return operation.whenComplete(() => _refreshOperation = null);
  }

  Future<String?> _performRefresh() async {
    try {
      final refreshToken = await readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;
      final response = await request(
        'POST',
        '/auth/mobile-refresh',
        body: {'refreshToken': refreshToken},
        retry: false,
      );
      final decoded = decodeBody(response);
      if (decoded is! Map<String, dynamic>) return null;
      final accessToken = decoded['accessToken'] as String?;
      final rotatedRefreshToken = decoded['refreshToken'] as String?;
      if (accessToken == null ||
          accessToken.isEmpty ||
          rotatedRefreshToken == null ||
          rotatedRefreshToken.isEmpty) {
        return null;
      }
      await saveAccessToken(accessToken);
      await saveRefreshToken(rotatedRefreshToken);
      return accessToken;
    } on Object catch (error) {
      if (kDebugMode) debugPrint('Token refresh failed: $error');
      await clearTokens();
      return null;
    }
  }
}
