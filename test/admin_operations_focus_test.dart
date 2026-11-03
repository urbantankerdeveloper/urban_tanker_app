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
  testWidgets('a focus request expands only the matching operations group',
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

    ExpansionTile tile(String title) => tester.widget<ExpansionTile>(
          find.byWidgetPredicate(
            (widget) =>
                widget is ExpansionTile &&
                widget.title is Text &&
                (widget.title as Text).data == title,
          ),
        );
    bool expanded(String title) => tile(title).controller!.isExpanded;

    expect(expanded('Reports & setup'), isFalse);

    focus.value = const OperationsFocus(OperationsSection.setup);
    await tester.pump();
    await tester.pump();

    expect(expanded('Reports & setup'), isTrue);
    expect(expanded('People & fleet'), isFalse);
    expect(expanded('Bookings & dispatch'), isFalse);
    expect(tester.takeException(), isNull);

    // The sections start real requests, which leave timers behind. Dispose the
    // tree and let them finish before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 15));
  });
}
