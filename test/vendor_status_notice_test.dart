import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/auth_feature_flags.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/models/vendor.dart';
import 'package:urban_tanker_app/screens/vendor/operations/vendor_status_notice.dart';
import 'package:urban_tanker_app/screens/vendor/operations/vendor_operations_screen.dart';
import 'package:urban_tanker_app/services/api_client.dart';

void main() {
  for (final (name, theme) in [
    ('light', buildLightTheme()),
    ('dark', buildDarkTheme()),
  ]) {
    testWidgets('shows vendor status clearly in the $name theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: VendorStatusNotice(
              profile: VendorBusinessProfile(
                id: 'vendor-1',
                businessName: 'North Tankers',
                serviceZone: 'North district',
                verification: 'pending',
                isOnline: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Awaiting approval'), findsOneWidget);
      expect(
        find.text('Your vendor application is being reviewed.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.hourglass_top_outlined), findsOneWidget);
    });
  }

  testWidgets('does not show a status notice for an approved online vendor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: VendorStatusNotice(
            profile: VendorBusinessProfile(
              id: 'vendor-1',
              businessName: 'North Tankers',
              serviceZone: 'North district',
              verification: 'approved',
              isOnline: true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Awaiting approval'), findsNothing);
    expect(find.text('You are offline'), findsNothing);
  });

  for (final (verification, isOnline, expectedTitle) in [
    ('approved', false, 'You are offline'),
    ('rejected', false, 'Application not approved'),
    ('suspended', false, 'Account suspended'),
  ]) {
    testWidgets('shows "$expectedTitle" for $verification vendor status', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          home: Scaffold(
            body: VendorStatusNotice(
              profile: VendorBusinessProfile(
                id: 'vendor-1',
                businessName: 'North Tankers',
                serviceZone: 'North district',
                verification: verification,
                isOnline: isOnline,
              ),
            ),
          ),
        ),
      );

      expect(find.text(expectedTitle), findsOneWidget);
    });
  }

  testWidgets(
    'vendor operations shows the profile notice when the new UI is enabled',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await tester.runAsync(SharedPreferences.getInstance);
      final controller = AppController(
        api: ApiClient(),
        preferences: preferences!,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appControllerProvider.overrideWith((ref) => controller),
            vendorOrdersProvider.overrideWith((ref) async => []),
            vendorOfflineMutationsProvider.overrideWith((ref) async => []),
            vendorProfileProvider.overrideWith(
              (ref) async => const VendorBusinessProfile(
                id: 'vendor-1',
                businessName: 'North Tankers',
                serviceZone: 'North district',
                verification: 'pending',
                isOnline: false,
              ),
            ),
          ],
          child: MaterialApp(
            theme: buildLightTheme(),
            home: const Scaffold(body: VendorOperationsScreen()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.text('Awaiting approval'),
        AuthFeatureFlags.newUiEnabled ? findsOneWidget : findsNothing,
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
    skip: !AuthFeatureFlags.newUiEnabled,
  );
}
