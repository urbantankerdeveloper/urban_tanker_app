import 'package:http/http.dart' as http;

/// What the domain API classes need from the HTTP layer. [ApiClient] implements
/// it and passes itself to them, so a subclass override of any method here is
/// seen by every endpoint.
abstract interface class ApiTransport {
  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    String contentType = 'application/json',
    bool retry = true,
  });

  /// Sends a request that is not an API call, such as a signed file upload.
  Future<http.Response> sendRequest(
    http.BaseRequest request, {
    Duration timeout = const Duration(seconds: 20),
  });

  void invalidateReadCache({String? path});

  Future<void> saveAccessToken(String token);

  Future<void> saveRefreshToken(String token);
}
