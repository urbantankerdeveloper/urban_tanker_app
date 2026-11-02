final _trackingToken = RegExp(r'^[A-Za-z0-9_-]{40,60}$');

/// Web hosts whose `https://<host>/track/<token>` links open the tracking screen.
/// Add the production web host here once its assetlinks.json is published.
const trackingWebHosts = <String>{};

/// Reads the booking token from `urbantanker://track/<token>` or
/// `https://<allow-listed host>/track/<token>`. Every other link is rejected.
String? trackingTokenFromUri(
  Uri uri, {
  Set<String> webHosts = trackingWebHosts,
}) {
  final List<String> segments;
  if (uri.scheme == 'urbantanker') {
    segments = [uri.host, ...uri.pathSegments];
  } else if (uri.scheme == 'https' && webHosts.contains(uri.host)) {
    segments = uri.pathSegments;
  } else {
    return null;
  }
  if (segments.length != 2 || segments.first != 'track') return null;
  final token = segments.last;
  return _trackingToken.hasMatch(token) ? token : null;
}
