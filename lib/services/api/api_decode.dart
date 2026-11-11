import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../models/account.dart';
import 'api_transport.dart';

const _invalidServerResponse = 'The server sent an unexpected response.';
const _backgroundDecodeThreshold = 64 * 1024;
final _decodedBodies = Expando<_DecodedBody>();
final _decodeOperations = Expando<Future<dynamic>>();

class _DecodedBody {
  const _DecodedBody(this.value);

  final dynamic value;
}

dynamic _decodeJson(String body) => jsonDecode(body);

/// Decodes a JSON body. A non-JSON body gives a generic message, not the
/// parser's raw text.
dynamic decodeBody(http.Response response) {
  final cached = _decodedBodies[response];
  if (cached != null) return cached.value;
  try {
    final decoded = jsonDecode(response.body);
    _decodedBodies[response] = _DecodedBody(decoded);
    return decoded;
  } on FormatException {
    throw const FormatException(_invalidServerResponse);
  }
}

/// Decodes large JSON responses in a background isolate and reuses the result
/// when the same cached HTTP response is read again.
Future<dynamic> decodeBodyAsync(http.Response response) {
  final cached = _decodedBodies[response];
  if (cached != null) return Future<dynamic>.value(cached.value);

  final active = _decodeOperations[response];
  if (active != null) return active;

  late final Future<dynamic> operation;
  operation = _decodeResponse(response).then((decoded) {
    _decodedBodies[response] = _DecodedBody(decoded);
    return decoded;
  }).whenComplete(() {
    if (identical(_decodeOperations[response], operation)) {
      _decodeOperations[response] = null;
    }
  });
  _decodeOperations[response] = operation;
  return operation;
}

Future<dynamic> _decodeResponse(http.Response response) async {
  try {
    if (response.bodyBytes.length >= _backgroundDecodeThreshold) {
      return await compute(_decodeJson, response.body);
    }
    return jsonDecode(response.body);
  } on FormatException {
    throw const FormatException(_invalidServerResponse);
  }
}

Future<Map<String, dynamic>> mapResponse(
  http.Response response,
  String label,
) async {
  final decoded = await decodeBodyAsync(response);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('The $label response was invalid.');
  }
  return decoded;
}

Future<List<Map<String, dynamic>>> mapList(
  http.Response response,
  String label,
) async {
  final decoded = await decodeBodyAsync(response);
  if (decoded is! List) {
    throw FormatException('The $label response was invalid.');
  }
  return decoded.whereType<Map<String, dynamic>>().toList();
}

Future<List<T>> parseList<T>(
  http.Response response,
  T Function(Map<String, dynamic>) parse,
  String label,
) async {
  final decoded = await decodeBodyAsync(response);
  if (decoded is! List) {
    throw FormatException('The $label response was invalid.');
  }

  return decoded.whereType<Map<String, dynamic>>().map(parse).toList();
}

/// GETs a list endpoint and wraps each object as an [AccountRecord].
Future<List<AccountRecord>> recordList(
  ApiTransport api,
  String path,
  String label,
) async {
  final response = await api.request('GET', path);
  final decoded = await decodeBodyAsync(response);
  if (decoded is! List) {
    throw FormatException('The $label response was invalid.');
  }
  return decoded
      .whereType<Map<String, dynamic>>()
      .map(AccountRecord.new)
      .toList();
}
