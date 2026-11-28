import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/realtime_service.dart';

void main() {
  test('does not open a socket connection without an access token', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var requestCount = 0;
    final requests = server.listen((request) async {
      requestCount += 1;
      await request.response.close();
    });
    final service = RealtimeService(
      socketUrl: 'http://127.0.0.1:${server.port}',
      readToken: () async => null,
    );

    try {
      service.connect((event, payload) {});
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(requestCount, 0);
    } finally {
      service.dispose();
      await requests.cancel();
      await server.close(force: true);
    }
  });
}
