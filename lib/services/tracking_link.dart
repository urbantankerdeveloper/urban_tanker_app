final _trackingToken = RegExp(r'^[A-Za-z0-9_-]{40,60}$');

/// Reads the booking token from `urbantanker://track/<token>` or `https://<host>/track/<token>`.
String? trackingTokenFromUri(Uri uri) {
  final segments = uri.scheme == 'urbantanker'
      ? [uri.host, ...uri.pathSegments]
      : uri.pathSegments;
  if (segments.length != 2 || segments.first != 'track') return null;
  final token = segments.last;
  return _trackingToken.hasMatch(token) ? token : null;
}
