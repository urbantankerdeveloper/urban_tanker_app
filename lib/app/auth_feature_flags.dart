/// Switches for auth features that depend on backend endpoints.
abstract final class AuthFeatureFlags {
  /// Sign-in and sign-up with a one-time code sent by email. If the server
  /// answers 404 or 501 for the code endpoints, the app switches the option off
  /// at runtime and keeps password sign-in working.
  static const emailOtp = true;
}
