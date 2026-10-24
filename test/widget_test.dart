import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:urban_tanker_app/app/app.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/services/api_client.dart';

void main() {
  testWidgets('app opens the sign-in screen when no session exists',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller = AppController(
      api: ApiClient(baseUrl: 'https://example.test/api'),
      preferences: await SharedPreferences.getInstance(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith((ref) => controller),
        ],
        child: const UrbanTankerApp(),
      ),
    );

    expect(find.text('Water, organised.'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
