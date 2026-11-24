import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/api_base.dart';

void main() {
  test('derives the Socket.IO origin from the API URL for rollback too', () {
    expect(apiOriginForBaseUrl('https://api.urbantanker.in/api'),
        'https://api.urbantanker.in');
    expect(apiOriginForBaseUrl('https://urban-tanker-backend.onrender.com/api'),
        'https://urban-tanker-backend.onrender.com');
  });
}
