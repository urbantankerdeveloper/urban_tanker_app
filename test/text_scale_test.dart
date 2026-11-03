import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';

Widget _scaled(Widget child) => MaterialApp(
      theme: buildLightTheme(),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.5),
        ),
        child: Scaffold(body: child),
      ),
    );

void main() {
  testWidgets('error and empty states do not overflow at 1.5x text',
      (tester) async {
    await tester.pumpWidget(
      _scaled(
        AppStateView.error(
          error: Exception('The server rejected the request.'),
          onRetry: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _scaled(
        const AppStateView.empty(
          icon: Icons.receipt_long_outlined,
          message: 'Your bookings will appear here.',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline errors do not overflow at 1.5x text', (tester) async {
    await tester.pumpWidget(
      _scaled(
        AppStateInline.error(
          error: Exception('Something failed'),
          onRetry: () {},
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
