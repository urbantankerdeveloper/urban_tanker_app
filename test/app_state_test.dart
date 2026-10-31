import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/app/page_components.dart';

void main() {
  testWidgets('network errors show an offline state with a retry action',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppStateView.error(
            error: Exception('SocketException: Network is unreachable'),
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    expect(find.text('No network connection'), findsOneWidget);
    await tester.tap(find.text('Try again'));
    expect(retried, isTrue);
  });

  testWidgets('non-network errors retain an actionable error state',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppStateView.error(
            error: Exception('The server rejected the request.'),
          ),
        ),
      ),
    );

    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Exception: The server rejected the request.'),
        findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('loading and empty states have consistent status UI',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppStateView.empty(message: 'No results.'),
        ),
      ),
    );
    expect(find.text('Nothing here yet'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppStateView.loading()),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
