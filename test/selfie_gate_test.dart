import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/models/session.dart';

void main() {
  test('reads the selfie requirement from the session user', () {
    final user = SessionUser.fromJson({
      'id': 'user-1',
      'name': 'Asha',
      'username': 'asha',
      'role': 'customer',
      'selfieRequired': true,
    });

    expect(user.selfieRequired, isTrue);
    expect(user.copyWith(selfieRequired: false).selfieRequired, isFalse);
  });

  test('treats a missing flag as no selfie required', () {
    final user = SessionUser.fromJson({
      'id': 'user-2',
      'name': 'Ravi',
      'username': 'ravi',
      'role': 'customer',
    });

    expect(user.selfieRequired, isFalse);
  });
}
