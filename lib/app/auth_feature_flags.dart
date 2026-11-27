/// Switches for auth features that depend on backend endpoints.
abstract final class AuthFeatureFlags {
  /// Enables the phased visual redesign while the legacy interface remains
  /// available by default. Turn on with `--dart-define=NEW_UI_ENABLED=true`.
  static const newUiEnabled = bool.fromEnvironment(
    'NEW_UI_ENABLED',
    defaultValue: false,
  );

  /// Sign-in and sign-up with a one-time code sent by email. If the server
  /// answers 404 or 501 for the code endpoints, the app switches the option off
  /// at runtime and keeps password sign-in working.
  /// Off by default in debug, staging and release. Turn on with
  /// `--dart-define=EMAIL_OTP_ENABLED=true`.
  static const emailOtp = bool.fromEnvironment(
    'EMAIL_OTP_ENABLED',
    defaultValue: false,
  );

  /// Prompts signed-in users to verify their phone. Turn on with
  /// `--dart-define=PHONE_VERIFY_DIALOG_ENABLED=true`.
  static const phoneVerifyDialog = bool.fromEnvironment(
    'PHONE_VERIFY_DIALOG_ENABLED',
    defaultValue: false,
  );

  /// Shows the My Profile item in the workspace menu.
  /// Enable with `--dart-define=PROFILE_MENU_ENABLED=true`.
  static const profileMenu = bool.fromEnvironment(
    'PROFILE_MENU_ENABLED',
    defaultValue: false,
  );

  /// Parent orders with independent service fulfilments.
  /// Enable with `--dart-define=MULTI_SERVICE_ORDERS_ENABLED=true`.
  static const multiServiceOrders = bool.fromEnvironment(
    'MULTI_SERVICE_ORDERS_ENABLED',
    defaultValue: false,
  );
}
