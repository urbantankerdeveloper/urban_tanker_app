const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://api.urbantanker.in/api',
);

String apiOriginForBaseUrl(String baseUrl) => Uri.parse(baseUrl).origin;

final apiSocketUrl = apiOriginForBaseUrl(apiBaseUrl);
