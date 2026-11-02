import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/masking.dart';

void main() {
  test('masks the local part of an email and keeps the domain', () {
    expect(maskEmail('asha.rao@example.com'), 'as***@example.com');
    expect(maskEmail('ab@example.com'), 'a***@example.com');
    expect(maskEmail(''), '');
  });

  test('keeps only the last four digits of a phone number', () {
    expect(maskPhone('+91 98765 43210'), '********3210');
    expect(maskPhone('9876543210'), '******3210');
    expect(maskPhone('1234'), '****');
    expect(maskPhone(''), '');
  });
}
