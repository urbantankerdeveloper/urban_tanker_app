import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_tanker_app/services/api_client.dart';
import 'package:urban_tanker_app/screens/profile_dialog.dart';

void main() {
  testWidgets('shows the signed-in profile details in a dialog',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showUserProfileDialog(
                context: context,
                api: ApiClient(),
                name: 'Taylor User',
                role: 'vendor',
                email: 'taylor@example.com',
                phone: '+911234567890',
                profilePhotoUrl: Future<String?>.value(),
                onSaved: (_) async {},
              ),
              child: const Text('Open profile'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open profile'));
    await tester.pumpAndSettle();

    expect(find.text('Taylor User'), findsOneWidget);
    expect(find.text('Vendor'), findsOneWidget);
    expect(find.text('taylor@example.com'), findsOneWidget);
    expect(find.text('+91'), findsOneWidget);
    expect(find.text('1234567890'), findsOneWidget);
  });
}
