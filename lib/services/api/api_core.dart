import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api_decode.dart';
import 'api_types.dart';

/// The HTTP layer every endpoint shares: the bearer token, one token refresh at
/// a time, GET-only retries and de-duplication, short read caching, slow-server
/// diagnostics and error messages.
class ApiCore {
  ApiCore({
    required http.Client client,
    required FlutterSecureStorage storage,
    required this.baseUrl,
    required Future<String?> Function() tokenReader,
    Duration getTimeout = _defaultGetTimeout,
    Duration requestTimeout = _defaultRequestTimeout,
    Duration getRetryBudget = _defaultGetRetryBudget,
    List<Duration> retryDelays = _defaultRetryDelays,
    Duration readCacheTtl = _defaultReadCacheTtl,
    DateTime Function()? clock,
  })  : _client = client,
        _storage = storage,
        _tokenReader = tokenReader,
        _getTimeout = getTimeout,
        _requestTimeout = requestTimeout,
        _getRetryBudget = getRetryBudget,
        _retryDelays = retryDelays,
        _readCacheTtl = readCacheTtl,
        _clock = clock ?? DateTime.now;

  static const _defaultGetTimeout = Duration(seconds: 8);
  static const _defaultRequestTimeout = Duration(seconds: 20);
  static const _defaultGetRetryBudget = Duration(seconds: 12);
  static const _defaultReadCacheTtl = Duration(seconds: 90);
  static const _slowRequestThreshold = Duration(seconds: 2);
  static const _cacheableGetPaths = {
    '/customer/services',
    '/customer/offers',
    '/customer/membership-plans',
    '/vendor/services',
  };
  static const _defaultRetryDelays = [
    Duration(milliseconds: 400),
    Duration(milliseconds: 1200),
  ];
  static const _retryableStatusCodes = {502, 503, 504};

  final http.Client _client;
  final FlutterSecureStorage _storage;
  final Future<String?> Function() _tokenReader;
  final Duration _getTimeout;
  final Duration _requestTimeout;
  final Duration _getRetryBudget;
  final List<Duration> _retryDelays;
  final Duration _readCacheTtl;
  final DateTime Function() _clock;
  final String baseUrl;
  final _readCache = <String, _CachedResponse>{};
  final _inflightGetRequests = <String, Future<http.Response>>{};
  Future<String?>? _refreshOperation;
  int _readCacheGeneration = 0;

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
    invalidateReadCache();
  }

  void invalidateReadCache({String? path}) {
    _readCacheGeneration++;
    if (path == null) {
      _readCache.clear();
      _inflightGetRequests.clear();
      return;
    }
    final key = _cacheKey(path);
    final requestKeys = _readCache.keys
        .where(
            (requestKey) => requestKey == key || requestKey.startsWith('$key?'))
        .toList();
    for (final requestKey in requestKeys) {
      _readCache.remove(requestKey);
    }
    _inflightGetRequests.removeWhere(
      (requestKey, _) =>
          requestKey.startsWith('$key::') || requestKey.startsWith('$key?'),
    );
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
    Duration? timeout,
  }) {
    final requestTimeout = timeout ??
        (method.toUpperCase() == 'GET' ? _getTimeout : _requestTimeout);
    final uri = Uri.parse('$baseUrl$path');
    final cacheKey = _cacheKey(path);
    final isGet = method.toUpperCase() == 'GET';
    final isBodylessGet = isGet && body == null && bodyBytes == null;
    final isCacheable =
        isBodylessGet && _cacheableGetPaths.contains(_endpointPath(uri));
    if (isCacheable) {
      final cached = _readCache[cacheKey];
      if (cached != null) {
        if (_clock().isBefore(cached.expiresAt)) {
          return Future<http.Response>.value(cached.response);
        }
        _readCache.remove(cacheKey);
      }
    }

    final flightKey = '$cacheKey::$retry::${requestTimeout.inMicroseconds}';
    if (isBodylessGet) {
      final active = _inflightGetRequests[flightKey];
      if (active != null) return active;
    }

    final generation = _readCacheGeneration;
    final requestFuture = _performRequest(
      method,
      path,
      body: body,
      bodyBytes: bodyBytes,
      contentType: contentType,
      retry: retry,
      timeout: requestTimeout,
      cacheKey: isCacheable ? cacheKey : null,
      cacheGeneration: generation,
    );
    if (!isBodylessGet) return requestFuture;

    late final Future<http.Response> sharedFuture;
    sharedFuture = requestFuture.whenComplete(() {
      if (identical(_inflightGetRequests[flightKey], sharedFuture)) {
        _inflightGetRequests.remove(flightKey);
      }
    });
    _inflightGetRequests[flightKey] = sharedFuture;
    return sharedFuture;
  }

  Future<http.Response> _performRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    required String contentType,
    required bool retry,
    required Duration timeout,
    required String? cacheKey,
    required int cacheGeneration,
  }) async {
    final stopwatch = Stopwatch()..start();
    int? statusCode;
    try {
      final response = await _requestOnce(
        method,
        path,
        body: body,
        bodyBytes: bodyBytes,
        contentType: contentType,
        retry: retry,
        timeout: timeout,
        stopwatch: stopwatch,
      );
      statusCode = response.statusCode;
      if (cacheKey != null &&
          response.statusCode >= 200 &&
          response.statusCode < 300 &&
          _readCacheGeneration == cacheGeneration) {
        _readCache[cacheKey] = _CachedResponse(
          response: response,
          expiresAt: _clock().add(_readCacheTtl),
        );
      }
      return response;
    } on ApiException catch (error) {
      statusCode = error.statusCode;
      rethrow;
    } finally {
      _logSlowRequest(
        method,
        Uri.parse('$baseUrl$path'),
        stopwatch,
        statusCode,
      );
    }
  }

  String _cacheKey(String path) => Uri.parse('$baseUrl$path').toString();

  String _endpointPath(Uri uri) {
    final basePath = Uri.parse(baseUrl).path;
    if (basePath.isEmpty || !uri.path.startsWith('$basePath/')) {
      return uri.path;
    }
    return uri.path.substring(basePath.length);
  }

  Future<http.Response> sendRequest(
    http.BaseRequest request, {
    Duration timeout = const Duration(seconds: 20),
  }) =>
      _sendRequest(request, timeout: timeout, logSlowRequest: true);

  Future<http.Response> _sendRequest(
    http.BaseRequest request, {
    required Duration timeout,
    required bool logSlowRequest,
  }) async {
    final stopwatch = Stopwatch()..start();
    int? statusCode;
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      statusCode = response.statusCode;
      return response;
    } finally {
      if (logSlowRequest) {
        _logSlowRequest(
          request.method,
          request.url,
          stopwatch,
          statusCode,
        );
      }
    }
  }

  void _logSlowRequest(
    String method,
    Uri uri,
    Stopwatch stopwatch,
    int? statusCode,
  ) {
    if (!kDebugMode || stopwatch.elapsed < _slowRequestThreshold) return;
    final result =
        statusCode == null ? 'without a response' : '(HTTP $statusCode)';
    debugPrint(
      'Slow HTTP request: $method ${uri.path} $result '
      'in ${stopwatch.elapsed.inMilliseconds}ms',
    );
  }

  Future<http.Response> _requestOnce(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    String contentType = 'application/json',
    bool retry = true,
    required Duration timeout,
    required Stopwatch stopwatch,
  }) async {
    final response = await _sendWithRetries(
      method,
      path,
      body: body,
      bodyBytes: bodyBytes,
      contentType: contentType,
      timeout: timeout,
      stopwatch: stopwatch,
    );

    if (response.statusCode == 401 && retry && path != '/auth/mobile-refresh') {
      final refreshTimeout = method.toUpperCase() == 'GET'
          ? _getRetryBudget - stopwatch.elapsed
          : null;
      if (refreshTimeout != null && refreshTimeout <= Duration.zero) {
        throw TimeoutException('GET request exceeded its retry time budget.');
      }
      final newToken = await _refreshAccessToken(timeout: refreshTimeout);
      if (newToken != null) {
        return _requestOnce(
          method,
          path,
          body: body,
          bodyBytes: bodyBytes,
          contentType: contentType,
          retry: false,
          timeout: timeout,
          stopwatch: stopwatch,
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

  /// Sends the request. Only GET requests are retried after timeouts, network
  /// errors and 502/503/504 responses. Writes are never sent twice.
  Future<http.Response> _sendWithRetries(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    required String contentType,
    required Duration timeout,
    required Stopwatch stopwatch,
  }) async {
    final isGet = method.toUpperCase() == 'GET';
    for (var attempt = 0;; attempt++) {
      final canRetry = isGet && attempt < _retryDelays.length;
      final remainingBudget = _getRetryBudget - stopwatch.elapsed;
      if (isGet && remainingBudget <= Duration.zero) {
        throw TimeoutException('GET request exceeded its retry time budget.');
      }
      final attemptTimeout =
          isGet && remainingBudget < timeout ? remainingBudget : timeout;
      try {
        final response = await _sendOnce(
          method,
          path,
          body: body,
          bodyBytes: bodyBytes,
          contentType: contentType,
          timeout: attemptTimeout,
        );
        if (!canRetry || !_retryableStatusCodes.contains(response.statusCode)) {
          return response;
        }
        final delay = _retryDelays[attempt];
        if (stopwatch.elapsed + delay >= _getRetryBudget) return response;
        await Future<void>.delayed(delay);
      } catch (error) {
        if (!canRetry || !_isNetworkFailure(error)) rethrow;
        final delay = _retryDelays[attempt];
        if (stopwatch.elapsed + delay >= _getRetryBudget) rethrow;
        await Future<void>.delayed(delay);
      }
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
    required Duration timeout,
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
    return _sendRequest(
      httpRequest,
      timeout: timeout,
      logSlowRequest: false,
    );
  }

  Future<String?> _refreshAccessToken({Duration? timeout}) {
    final active = _refreshOperation;
    if (active != null) {
      return timeout == null ? active : active.timeout(timeout);
    }
    final operation = _performRefresh(timeout: timeout);
    _refreshOperation = operation;
    final sharedOperation =
        operation.whenComplete(() => _refreshOperation = null);
    return timeout == null ? sharedOperation : sharedOperation.timeout(timeout);
  }

  Future<String?> _performRefresh({Duration? timeout}) async {
    try {
      final refreshToken = await readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return null;
      final response = await request(
        'POST',
        '/auth/mobile-refresh',
        body: {'refreshToken': refreshToken},
        retry: false,
        timeout: timeout,
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

class _CachedResponse {
  const _CachedResponse({required this.response, required this.expiresAt});

  final http.Response response;
  final DateTime expiresAt;
}
