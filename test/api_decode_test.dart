import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:urban_tanker_app/services/api/api_decode.dart';

void main() {
  test('large JSON lists decode and are memoized per response', () async {
    final description = List.filled(80, 'x').join();
    final payload = List.generate(
      1200,
      (index) => {'id': index, 'description': 'item-$description'},
    );
    final response = http.Response(jsonEncode(payload), 200);

    final decoded = await decodeBodyAsync(response);

    expect(decoded, hasLength(1200));
    expect((decoded.first as Map<String, dynamic>)['id'], 0);
    expect(identical(decodeBody(response), decoded), isTrue);
  });

  test('large malformed responses keep the generic decoding error', () async {
    final response = http.Response(List.filled(70 * 1024, 'x').join(), 200);

    await expectLater(
      decodeBodyAsync(response),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'The server sent an unexpected response.',
        ),
      ),
    );
  });
}
