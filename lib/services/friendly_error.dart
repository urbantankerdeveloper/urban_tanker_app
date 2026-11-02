import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Maps an error to a short message that is safe to show to users. Raw
/// exception text (class names, stack details, server internals) never reaches
/// the screen.
String friendlyError(Object error) {
  if (error is TimeoutException) {
    return 'The request took too long. Please try again.';
  }
  if (error is SocketException) {
    return 'No network connection. Check your connection and try again.';
  }
  if (error is HandshakeException) {
    return 'We could not open a secure connection. Please try again.';
  }
  if (error is FormatException) {
    return 'The server sent an unexpected response.';
  }
  if (error is ApiException) return _apiMessage(error);
  // Some screens throw StateError with a message written for the user.
  if (error is StateError) return error.message.toString();
  if (kDebugMode) debugPrint('Unmapped error: $error');
  return 'Something went wrong. Please try again.';
}

String _apiMessage(ApiException error) {
  final status = error.statusCode;
  // Messages sent by the server are written for users, so they are shown as
  // they are. The client's own fallback text is replaced by a status message.
  final sentByServer = error.message.isNotEmpty &&
      error.message != ApiException.genericFailureMessage(status);
  if (sentByServer) return error.message;
  return switch (status) {
    401 => 'Your session has expired. Please sign in again.',
    403 => "You don't have permission to do that.",
    404 => "We couldn't find that. It may have been removed.",
    408 => 'The request took too long. Please try again.',
    429 => 'Too many requests. Please wait a moment and try again.',
    >= 500 => 'The server is having trouble. Please try again shortly.',
    _ => 'Something went wrong. Please try again.',
  };
}
