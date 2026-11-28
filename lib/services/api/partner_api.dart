import 'api_decode.dart';
import 'api_transport.dart';

class PartnerApplicationReceipt {
  const PartnerApplicationReceipt({
    required this.reference,
    required this.status,
    required this.message,
  });

  final String reference;
  final String status;
  final String message;
}

/// Public partner application and verification endpoints.
class PartnerApi {
  PartnerApi(this._api);

  final ApiTransport _api;

  Future<bool> partnerApplicationOtpRequired() async {
    final response = await _api.request('GET', '/config/flags');
    final decoded = decodeBody(response);
    if (decoded is! Map<String, dynamic> ||
        decoded['partner_application_otp_enabled'] is! bool) {
      throw const FormatException(
        'The partner application flags were invalid.',
      );
    }
    return decoded['partner_application_otp_enabled'] as bool;
  }

  Future<String> requestPartnerApplicationOtp(String phone) async {
    final response = await _api.request(
      'POST',
      '/auth/partner/request-otp',
      body: {'phone': phone},
      retry: false,
    );
    final decoded = await mapResponse(response, 'partner phone verification');
    if (decoded['challengeId'] is! String) {
      throw const FormatException(
        'The partner phone verification was invalid.',
      );
    }
    return decoded['challengeId'] as String;
  }

  Future<void> verifyPartnerApplicationOtp({
    required String phone,
    required String challengeId,
    required String otp,
  }) async {
    final response = await _api.request(
      'POST',
      '/auth/partner/verify-otp',
      body: {'phone': phone, 'challengeId': challengeId, 'otp': otp},
      retry: false,
    );
    final decoded = await mapResponse(response, 'partner phone verification');
    if (decoded['verified'] != true) {
      throw const FormatException('The partner phone could not be verified.');
    }
  }

  Future<PartnerApplicationReceipt> submitPartnerApplication({
    required Map<String, dynamic> application,
  }) async {
    final response = await _api.request(
      'POST',
      '/partner/applications',
      body: application,
      retry: false,
    );
    final decoded = await mapResponse(response, 'partner application');
    if (decoded['ok'] != true ||
        decoded['reference'] is! String ||
        decoded['status'] is! String ||
        decoded['message'] is! String) {
      throw const FormatException(
        'The partner application response was invalid.',
      );
    }
    return PartnerApplicationReceipt(
      reference: decoded['reference'] as String,
      status: decoded['status'] as String,
      message: decoded['message'] as String,
    );
  }
}
