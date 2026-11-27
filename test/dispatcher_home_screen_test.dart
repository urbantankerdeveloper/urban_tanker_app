import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/core/design_system/new_ui_theme.dart';
import 'package:urban_tanker_app/screens/dispatcher/dispatch_home_screen.dart';
import 'package:urban_tanker_app/services/api_client.dart';

class _DispatcherApi extends ApiClient {
  final requestedStatuses = <String?>[];

  @override
  Future<Map<String, dynamic>> adminOrders({
    int page = 1,
    String? status,
    String? service,
    String? vendorId,
    String? from,
    String? to,
    bool? assigned,
    int pageSize = 25,
  }) async {
    requestedStatuses.add(status);
    return {
      'total': switch (status) {
        'pending_vendor' => 7,
        'vendor_assigned' => 2,
        'en_route' => 5,
        'delivered' => 3,
        _ => 0,
      },
    };
  }
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('overview shows backend counts and opens its destinations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _DispatcherApi();
    var ordersOpened = false;
    var liveOpened = false;
    var alertsOpened = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          sessionUserIdProvider.overrideWithValue('dispatcher-1'),
        ],
        child: MaterialApp(
          theme: buildNewUiLightTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: Scaffold(
            body: DispatcherHomeScreen(
              onOpenOrders: () => ordersOpened = true,
              onOpenLive: () => liveOpened = true,
              onOpenAlerts: () => alertsOpened = true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('7'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(api.requestedStatuses, [
      'pending_vendor',
      'vendor_assigned',
      'en_route',
      'delivered',
    ]);

    for (final label in ['View orders', 'Live fleet map', 'Open alerts']) {
      await tester.scrollUntilVisible(
        find.text(label),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(label));
    }
    expect(ordersOpened, isTrue);
    expect(liveOpened, isTrue);
    expect(alertsOpened, isTrue);
    expect(tester.takeException(), isNull);
  });
}
