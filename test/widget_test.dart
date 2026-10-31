import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:urban_tanker_app/app/app.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/services/api_client.dart';

void main() {
  testWidgets('app opens registration with a login option when signed out',
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

    expect(find.text('Create your account.'), findsOneWidget);
    expect(find.text('Already a user? Log in'), findsOneWidget);
    expect(find.text('Send verification code'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
