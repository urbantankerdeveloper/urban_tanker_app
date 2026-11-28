import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_tanker_app/app/auth_feature_flags.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/new_ui_theme.dart';
import 'package:urban_tanker_app/core/design_system/widgets/state_views.dart';
import 'package:urban_tanker_app/screens/bookings_screen.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('empty order screen offers booking in both themes', (
    tester,
  ) async {
    if (!AuthFeatureFlags.newUiEnabled) return;
    for (final theme in [buildNewUiLightTheme(), buildNewUiDarkTheme()]) {
      var booked = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingsProvider.overrideWith(_EmptyBookingsNotifier.new),
          ],
          child: MaterialApp(
            theme: theme,
            home: Scaffold(
              body: BookingsScreen(
                onBook: () async {
                  booked = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.byType(NewUiEmptyState), findsOneWidget);
      await tester.tap(find.text('Book service'));
      expect(booked, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

class _EmptyBookingsNotifier extends BookingsNotifier {
  @override
  Future<BookingsState> build() async => const BookingsState(items: []);
}
