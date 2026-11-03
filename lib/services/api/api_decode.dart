import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/account.dart';
import 'api_transport.dart';

const _invalidServerResponse = 'The server sent an unexpected response.';

/// Decodes a JSON body. A non-JSON body gives a generic message, not the
/// parser's raw text.
dynamic decodeBody(http.Response response) {
  try {
    return jsonDecode(response.body);
  } on FormatException {
    throw const FormatException(_invalidServerResponse);
  }
}

Future<Map<String, dynamic>> mapResponse(
  http.Response response,
  String label,
) async {
  final decoded = decodeBody(response);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('The $label response was invalid.');
  }
  return decoded;
}

Future<List<Map<String, dynamic>>> mapList(
  http.Response response,
  String label,
) async {
  final decoded = decodeBody(response);
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
  final decoded = decodeBody(response);
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
  final decoded = decodeBody(response);
  if (decoded is! List) {
    throw FormatException('The $label response was invalid.');
  }
  return decoded
      .whereType<Map<String, dynamic>>()
      .map(AccountRecord.new)
      .toList();
}
