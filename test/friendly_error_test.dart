import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/api_client.dart';
import 'package:urban_tanker_app/services/friendly_error.dart';

void main() {
  test('network and parsing errors map to short messages', () {
    expect(
      friendlyError(TimeoutException('slow')),
      'The request took too long. Please try again.',
    );
    expect(
      friendlyError(const SocketException('refused')),
      'No network connection. Check your connection and try again.',
    );
    expect(
      friendlyError(const FormatException('bad json')),
      'The server sent an unexpected response.',
    );
  });

  test('server messages are shown as they are', () {
    expect(
      friendlyError(const ApiException('Invalid password.', 401)),
      'Invalid password.',
    );
    expect(
      friendlyError(const ApiException('Mobile verification is off.', 503)),
      'Mobile verification is off.',
    );
  });

  test('status codes give a message when the server sent no text', () {
    expect(
      friendlyError(
        ApiException(ApiException.genericFailureMessage(401), 401),
      ),
      'Your session has expired. Please sign in again.',
    );
    expect(
      friendlyError(ApiException(ApiException.genericFailureMessage(502), 502)),
      'The server is having trouble. Please try again shortly.',
    );
  });

  test('state errors keep their user-facing text', () {
    expect(
      friendlyError(StateError('This booking is no longer available.')),
      'This booking is no longer available.',
    );
  });
}
