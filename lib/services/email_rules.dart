/// Email rules shared by the API client and the sign-in screens.
///
/// The pattern is a practical subset of RFC 5322: it rejects obvious typos
/// (missing @, spaces, no dot in the domain) without trying to accept every
/// address the RFC allows. The server has the final say.
final _emailPattern = RegExp(
  r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?"
  r'(?:\.[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?)+$',
);

/// Trims and lowercases an address, so that "  Asha@Example.com " and
/// "asha@example.com" are the same account everywhere in the app.
String normalizeEmail(String value) => value.trim().toLowerCase();

/// True when [value] is a plausible address after normalization.
bool isValidEmail(String value) {
  final normalized = normalizeEmail(value);
  return normalized.length <= 254 && _emailPattern.hasMatch(normalized);
}
