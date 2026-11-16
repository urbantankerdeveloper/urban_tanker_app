import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

typedef GeocodingRequest = Future<http.Response> Function(Uri uri);

class GoogleReverseGeocodingService {
  GoogleReverseGeocodingService({
    String? apiKey,
    GeocodingRequest? request,
  })  : _apiKey = apiKey ?? const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
        _request = request ?? _defaultRequest;

  final String _apiKey;
  final GeocodingRequest _request;

  Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw StateError('Address lookup is not configured.');
    }
    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '$latitude,$longitude',
        'key': _apiKey,
        'language': 'en',
        'region': 'in',
      },
    );
    final response = await _request(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw StateError(
        'Address lookup failed. Please try again or enter the address manually.',
      );
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The address lookup response was invalid.');
    }
    if (decoded['status'] != 'OK') {
      throw StateError(_messageForStatus(decoded['status']));
    }
    final results = decoded['results'];
    if (results is! List || results.isEmpty) {
      throw StateError(
        'No street address was found nearby. Please enter the address manually.',
      );
    }
    final firstResult = results.first;
    if (firstResult is! Map<String, dynamic>) {
      throw const FormatException('The address lookup response was invalid.');
    }
    final address = firstResult['formatted_address'];
    if (address is! String || address.trim().isEmpty) {
      throw StateError(
        'No street address was found nearby. Please enter the address manually.',
      );
    }
    return address.trim();
  }

  static Future<http.Response> _defaultRequest(Uri uri) => http.get(uri);

  static String _messageForStatus(Object? status) => switch (status) {
        'ZERO_RESULTS' =>
          'No street address was found nearby. Please enter the address manually.',
        'REQUEST_DENIED' =>
          'Address lookup is unavailable. Please enter the address manually.',
        'OVER_QUERY_LIMIT' =>
          'Address lookup is temporarily busy. Please enter the address manually.',
        _ =>
          'Address lookup failed. Please try again or enter the address manually.',
      };
}
