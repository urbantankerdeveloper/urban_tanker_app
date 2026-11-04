import '../../models/session.dart';
import '../email_rules.dart';
import 'api_decode.dart';
import 'api_transport.dart';
import 'api_types.dart';

/// Sign-in, sign-up, phone and email verification, password reset and
/// preferences.
class AuthApi {
  AuthApi(this._api);

  static const _defaultResendAfterSeconds = 30;

  final ApiTransport _api;

  Future<void> logout(String refreshToken) async {
    await _api.request(
      'POST',
      '/auth/logout',
      body: {'refreshToken': refreshToken},
      retry: false,
    );
  }

  Future<AuthResult> login(String credential, String password) async {
    final body = credential.contains('@')
        ? {'email': credential, 'password': password}
        : {'username': credential, 'password': password};
    return _authRequest('/auth/login', body);
  }

  /// Creates the account. The server either signs the user in, or (when email
  /// confirmation is required) sends a code and returns its challenge.
  Future<SignUpOutcome> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? themeMode,
  }) async {
    final response = await _api.request('POST', '/auth/signup', body: {
      'email': email,
      'password': password,
      'name': name,
      'phone': phone,
      'role': 'customer',
      if (themeMode != null) 'themeMode': themeMode,
    });
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The registration response was invalid.');
    }
    if (decoded['requiresEmailVerification'] == true) {
      if (decoded['emailSent'] != true || decoded['challengeId'] is! String) {
        throw const FormatException(
          'The server did not confirm that the verification code was sent.',
        );
      }
      return (
        authResult: null,
        challengeId: decoded['challengeId'] as String,
        resendAfterSeconds: (decoded['resendAfterSeconds'] as num?)?.toInt() ??
            _defaultResendAfterSeconds,
      );
    }
    return (
      authResult: await _saveAuthResult(decoded),
      challengeId: null,
      resendAfterSeconds: 0,
    );
  }

  Future<void> requestPasswordReset(String email) async {
    final response = await _api.request(
      'POST',
      '/auth/password-reset',
      body: {'email': email.trim()},
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> || decoded['accepted'] != true) {
      throw const FormatException(
        'The password reset response was invalid.',
      );
    }
  }

  Future<String> requestPhoneAuthOtp(String phone) async {
    final normalized = normalizeIndianPhone(phone);
    if (!RegExp(r'^\d{10}$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid 10-digit mobile number.');
    }
    final response = await _api.request(
      'POST',
      '/auth/phone/request-otp',
      body: {'phone': normalized},
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> || decoded['challengeId'] is! String) {
      throw const FormatException('The phone sign-in response was invalid.');
    }
    return decoded['challengeId'] as String;
  }

  Future<AuthResult> verifyPhoneAuthOtp({
    required String phone,
    required String challengeId,
    required String otp,
    String? name,
  }) async {
    final normalized = normalizeIndianPhone(phone);
    if (!RegExp(r'^\d{10}$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid 10-digit mobile number.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp.trim())) {
      throw const FormatException('Enter the 6-digit verification code.');
    }
    final response = await _api.request(
      'POST',
      '/auth/phone/verify-otp',
      body: {
        'phone': normalized,
        'challengeId': challengeId,
        'otp': otp.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      },
      retry: false,
    );
    return _saveAuthResult(decodeBody(response));
  }

  Future<PhoneVerificationState> phoneVerification() async {
    final response = await _api.request('GET', '/customer/phone-verification');
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException(
          'The phone verification response was invalid.');
    }
    return PhoneVerificationState(
      phone: normalizeIndianPhone((decoded['phone'] ?? '').toString()),
      verified: decoded['verified'] == true,
    );
  }

  Future<String> requestPhoneOtp(String phone) async {
    final normalized = normalizeIndianPhone(phone);
    if (!RegExp(r'^\d{10}$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid 10-digit mobile number.');
    }
    final response = await _api.request(
      'POST',
      '/auth/guest/request-otp',
      body: {'phone': normalized},
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> || decoded['challengeId'] is! String) {
      throw const FormatException('The phone OTP response was invalid.');
    }
    return decoded['challengeId'] as String;
  }

  /// Sends the booking code to the phone and, when [email] is given, a second
  /// code to the email. Either challenge can be null if that channel is off.
  Future<
      ({
        String? challengeId,
        String? emailChallengeId,
        int resendAfterSeconds
      })> requestBookingOtp({required String phone, String? email}) async {
    final normalized = normalizeIndianPhone(phone);
    if (!RegExp(r'^\d{10}$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid 10-digit mobile number.');
    }
    final trimmedEmail = email == null ? null : normalizeEmail(email);
    if (trimmedEmail != null && !isValidEmail(trimmedEmail)) {
      throw const FormatException('Enter a valid email address.');
    }
    final response = await _api.request(
      'POST',
      '/auth/guest/request-otp',
      body: {
        'phone': normalized,
        if (trimmedEmail != null) 'email': trimmedEmail,
      },
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('The booking OTP response was invalid.');
    }
    final challengeId = decoded['challengeId'] as String?;
    final emailChallengeId = decoded['emailChallengeId'] as String?;
    if (challengeId == null && emailChallengeId == null) {
      throw const FormatException('The booking OTP response was invalid.');
    }
    return (
      challengeId: challengeId,
      emailChallengeId: emailChallengeId,
      resendAfterSeconds: (decoded['resendAfterSeconds'] as num?)?.toInt() ??
          _defaultResendAfterSeconds,
    );
  }

  /// Verifies the SMS code, the email code, or both. Send only the pair the
  /// user entered; each pair that is sent must be correct.
  Future<void> verifyPhoneOtp({
    required String phone,
    String? challengeId,
    String? otp,
    String? email,
    String? emailChallengeId,
    String? emailOtp,
  }) async {
    final response = await _api.request(
      'POST',
      '/auth/guest/verify-phone',
      body: {
        'phone': normalizeIndianPhone(phone),
        if (challengeId != null) 'challengeId': challengeId,
        if (otp != null) 'otp': otp.trim(),
        if (email != null) 'email': normalizeEmail(email),
        if (emailChallengeId != null) 'emailChallengeId': emailChallengeId,
        if (emailOtp != null) 'emailOtp': emailOtp.trim(),
      },
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> || decoded['verified'] != true) {
      throw const FormatException('Phone verification was not confirmed.');
    }
  }

  /// Sends a one-time code to [email]. Returns the challenge the code belongs to.
  Future<String> requestEmailAuthOtp(String email) async {
    final normalized = normalizeEmail(email);
    if (!isValidEmail(normalized)) {
      throw const FormatException('Enter a valid email address.');
    }
    final response = await _api.request(
      'POST',
      '/auth/email/request-otp',
      body: {'email': normalized},
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> || decoded['challengeId'] is! String) {
      throw const FormatException('The email code response was invalid.');
    }
    return decoded['challengeId'] as String;
  }

  /// Checks the code and signs in. New accounts also send [name] and [phone].
  Future<AuthResult> verifyEmailAuthOtp({
    required String email,
    required String challengeId,
    required String otp,
    String? name,
    String? phone,
  }) async {
    final normalized = normalizeEmail(email);
    if (!isValidEmail(normalized)) {
      throw const FormatException('Enter a valid email address.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp.trim())) {
      throw const FormatException('Enter the 6-digit verification code.');
    }
    final response = await _api.request(
      'POST',
      '/auth/email/verify-otp',
      body: {
        'email': normalized,
        'challengeId': challengeId,
        'otp': otp.trim(),
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (phone != null && phone.trim().isNotEmpty)
          'phone': normalizeIndianPhone(phone),
      },
      retry: false,
    );
    return _saveAuthResult(decodeBody(response));
  }

  Future<void> updateThemePreference(String themeMode) async {
    await _api.request(
      'PATCH',
      '/auth/preferences',
      body: {'themeMode': themeMode},
    );
  }

  Future<AuthResult> _authRequest(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _api.request('POST', path, body: body, retry: false);
    return _saveAuthResult(decodeBody(response));
  }

  Future<AuthResult> _saveAuthResult(dynamic body) async {
    if (body is! Map<String, dynamic>) {
      throw const FormatException('The authentication response was invalid.');
    }
    final result = AuthResult.fromJson(body);
    await _api.saveAccessToken(result.accessToken);
    if (result.refreshToken != null && result.refreshToken!.isNotEmpty) {
      await _api.saveRefreshToken(result.refreshToken!);
    }
    return result;
  }
}
