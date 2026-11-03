import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/models/workspace_navigation.dart';
import 'package:urban_tanker_app/screens/admin/admin_operations_screen.dart';
import 'package:urban_tanker_app/services/api_client.dart';

void main() {
  testWidgets('a focus request opens the matching operations section',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await tester.runAsync(SharedPreferences.getInstance);
    final controller = AppController(
      api: ApiClient(),
      preferences: preferences!,
    );
    final focus = ValueNotifier<OperationsFocus?>(null);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith((ref) => controller)],
        child: MaterialApp(
          home: Scaffold(body: AdminOperationsScreen(focus: focus)),
        ),
      ),
    );
    await tester.pump();

    int shownSection() =>
        tester.widget<IndexedStack>(find.byType(IndexedStack)).index!;

    expect(shownSection(), 0);

    focus.value = const OperationsFocus(OperationsSection.setup);
    await tester.pump();
    expect(shownSection(), 3);

    focus.value = const OperationsFocus(OperationsSection.finance);
    await tester.pump();
    expect(shownSection(), 2);
    expect(tester.takeException(), isNull);

    // The sections start real requests, which leave timers behind. Dispose the
    // tree and let them finish before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
  });
}
