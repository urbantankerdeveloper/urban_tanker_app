import '../../models/session.dart';
import 'api_decode.dart';
import 'api_transport.dart';
import 'api_types.dart';

/// Sign-in, sign-up, phone verification, password reset and preferences.
class AuthApi {
  AuthApi(this._api);

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

  Future<AuthResult?> signup({
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
      if (decoded['emailSent'] != true) {
        throw const FormatException(
          'The server did not confirm that the verification email was sent.',
        );
      }
      return null;
    }
    return _saveAuthResult(decoded);
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

  Future<void> verifyPhoneOtp({
    required String challengeId,
    required String phone,
    required String otp,
  }) async {
    final response = await _api.request(
      'POST',
      '/auth/guest/verify-phone',
      body: {
        'challengeId': challengeId,
        'phone': normalizeIndianPhone(phone),
        'otp': otp.trim(),
      },
      retry: false,
    );
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> || decoded['verified'] != true) {
      throw const FormatException('Phone verification was not confirmed.');
    }
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
