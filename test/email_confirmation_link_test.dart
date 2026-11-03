import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/email_confirmation_link.dart';
import 'package:urban_tanker_app/services/tracking_link.dart';

void main() {
  group('isEmailConfirmationLink', () {
    test('accepts the link the signup email opens', () {
      expect(
        isEmailConfirmationLink(
            Uri.parse('urbantanker://auth/email-confirmed')),
        isTrue,
      );
    });

    test('accepts the link when Supabase adds its token fragment', () {
      expect(
        isEmailConfirmationLink(
          Uri.parse(
              'urbantanker://auth/email-confirmed#access_token=abc&type=signup'),
        ),
        isTrue,
      );
    });

    test('rejects other auth paths, other hosts and other schemes', () {
      expect(isEmailConfirmationLink(Uri.parse('urbantanker://auth/reset')),
          isFalse);
      expect(
          isEmailConfirmationLink(
              Uri.parse('urbantanker://auth/email-confirmed/extra')),
          isFalse);
      expect(
          isEmailConfirmationLink(
              Uri.parse('urbantanker://track/email-confirmed')),
          isFalse);
      expect(
        isEmailConfirmationLink(
            Uri.parse('https://example.com/auth/email-confirmed')),
        isFalse,
      );
    });

    test('does not change how tracking links are read', () {
      const token = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUV';
      final tracking = Uri.parse('urbantanker://track/$token');

      expect(isEmailConfirmationLink(tracking), isFalse);
      expect(trackingTokenFromUri(tracking), token);
    });
  });
}
