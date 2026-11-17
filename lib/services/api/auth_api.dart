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
    String role = 'customer',
    String? businessName,
    String? serviceZone,
    double? latitude,
    double? longitude,
    String? selfieJpegBase64,
  }) async {
    final response = await _api.request('POST', '/auth/signup', body: {
      'email': email,
      'password': password,
      'name': name,
      'phone': phone,
      'role': role,
      if (businessName != null) 'businessName': businessName,
      if (serviceZone != null) 'serviceZone': serviceZone,
      if (latitude != null && longitude != null) 'latitude': latitude,
      if (latitude != null && longitude != null) 'longitude': longitude,
      if (selfieJpegBase64 != null) 'selfieJpegBase64': selfieJpegBase64,
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
      final phoneOtpSent = decoded['phoneOtpSent'] == true;
      final phoneChallengeId = decoded['phoneChallengeId'];
      if (phoneOtpSent && phoneChallengeId is! String) {
        throw const FormatException(
          'The server did not confirm that the mobile code was sent.',
        );
      }
      return (
        authResult: null,
        challengeId: decoded['challengeId'] as String,
        phoneChallengeId: phoneOtpSent ? phoneChallengeId as String : null,
        resendAfterSeconds: (decoded['resendAfterSeconds'] as num?)?.toInt() ??
            _defaultResendAfterSeconds,
      );
    }
    return (
      authResult: await _saveAuthResult(decoded),
      challengeId: null,
      phoneChallengeId: null,
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
      required: decoded['required'] != false,
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

  /// Sends the booking code to the phone and, when [email] is given, to email.
  /// Either challenge can be null when that channel is unavailable.
  Future<
      ({
        String? challengeId,
        String? emailChallengeId,
        bool phoneOtpSent,
        bool emailOtpSent,
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
    final phoneOtpSent = decoded['phoneOtpSent'];
    final emailOtpSent = decoded['emailOtpSent'];
    return (
      challengeId: challengeId,
      emailChallengeId: emailChallengeId,
      phoneOtpSent: phoneOtpSent is bool ? phoneOtpSent : challengeId != null,
      emailOtpSent:
          emailOtpSent is bool ? emailOtpSent : emailChallengeId != null,
      resendAfterSeconds: (decoded['resendAfterSeconds'] as num?)?.toInt() ??
          _defaultResendAfterSeconds,
    );
  }

  Future<String> requestRegisteredBookingEmailOtp({
    required String phone,
  }) async {
    final normalized = normalizeIndianPhone(phone);
    if (!RegExp(r'^\d{10}$').hasMatch(normalized)) {
      throw const FormatException('Enter a valid 10-digit mobile number.');
    }
    final response = await _api.request(
      'POST',
      '/auth/booking/email-fallback',
      body: {'phone': normalized},
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> ||
        decoded['emailChallengeId'] is! String) {
      throw const FormatException('The booking email response was invalid.');
    }
    return decoded['emailChallengeId'] as String;
  }

  /// Verifies the selected booking code using the same fields for either channel.
  Future<String> verifyPhoneOtp({
    required String phone,
    required String challengeId,
    required String otp,
    required String verificationChannel,
    String? email,
    String? phoneChallengeId,
    String? emailChallengeId,
  }) async {
    final response = await _api.request(
      'POST',
      '/auth/guest/verify-phone',
      body: {
        'phone': normalizeIndianPhone(phone),
        'challengeId': challengeId,
        'otp': otp.trim(),
        'verificationChannel': verificationChannel,
        if (email != null) 'email': normalizeEmail(email),
        if (phoneChallengeId != null) 'phoneChallengeId': phoneChallengeId,
        if (emailChallengeId != null) 'emailChallengeId': emailChallengeId,
      },
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> || decoded['verified'] != true) {
      throw const FormatException('Phone verification was not confirmed.');
    }
    return decoded['challengeId'] is String
        ? decoded['challengeId'] as String
        : challengeId;
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
    String? phoneChallengeId,
    String? phoneOtp,
  }) async {
    final normalized = normalizeEmail(email);
    if (!isValidEmail(normalized)) {
      throw const FormatException('Enter a valid email address.');
    }
    if (!RegExp(r'^\d{6}$').hasMatch(otp.trim())) {
      throw const FormatException('Enter the 6-digit verification code.');
    }
    if ((phoneChallengeId == null) != (phoneOtp == null) ||
        (phoneChallengeId != null &&
            (phone == null ||
                !RegExp(r'^\d{6}$').hasMatch(phoneOtp!.trim())))) {
      throw const FormatException(
        'Enter the verification code sent to this mobile number.',
      );
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
        if (phoneChallengeId != null) 'phoneChallengeId': phoneChallengeId,
        if (phoneOtp != null) 'phoneOtp': phoneOtp.trim(),
      },
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is Map<String, dynamic> && decoded['approvalPending'] == true) {
      throw AdminApprovalPendingException(_approvalMessage(decoded));
    }
    return _saveAuthResult(decoded);
  }

  Future<Map<String, bool>> featureFlags() async {
    final response = await _api.request(
      'GET',
      '/config/flags',
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> ||
        decoded['mpin_cooldown_enabled'] is! bool ||
        decoded.values.any((value) => value is! bool)) {
      throw const FormatException('The feature flags response was invalid.');
    }
    return decoded.map((key, value) => MapEntry(key, value as bool));
  }

  static String _approvalMessage(Map<String, dynamic> decoded) {
    final message = decoded['message'];
    return message is String && message.isNotEmpty
        ? message
        : 'Your account is waiting for approval from an existing admin.';
  }

  Future<void> updateThemePreference(String themeMode) async {
    await _api.request(
      'PATCH',
      '/auth/preferences',
      body: {'themeMode': themeMode},
    );
  }

  Future<void> saveMpin(String pin) async {
    await _api.request(
      'PUT',
      '/auth/mpin',
      body: {'pin': pin},
      retry: false,
    );
  }

  Future<void> deleteMpin() async {
    await _api.request('DELETE', '/auth/mpin', retry: false);
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
