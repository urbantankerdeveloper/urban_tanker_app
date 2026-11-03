import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';
import 'package:urban_tanker_app/core/design_system/design_system.dart';
import 'package:urban_tanker_app/core/design_system/gallery/design_system_gallery.dart';

Widget _host(
  Widget child, {
  ThemeData? theme,
  bool disableAnimations = false,
  double textScale = 1,
}) {
  return MaterialApp(
    theme: theme ?? buildLightTheme(),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 640),
        disableAnimations: disableAnimations,
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.gutter),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('core widgets render in light and dark at 1.3x text scale',
      (tester) async {
    final widgets = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BookingStatusChip(status: 'pending_vendor'),
        const GradientCard(child: Text('Next delivery')),
        const GlassCard(child: Text('Glass summary')),
        const StatCard(
          label: 'Deliveries today',
          value: '128',
          delta: '+12%',
          deltaUp: true,
          sparkline: [3, 5, 4, 7, 6, 9],
        ),
        PrimaryButton(label: 'Book a tanker', onPressed: () {}),
        SecondaryButton(label: 'Track order', onPressed: () {}),
        GhostButton(label: 'Help', onPressed: () {}),
        const AppTextField(label: 'Phone number'),
        OtpField(onChanged: (_) {}),
        SegmentedTabs(
          labels: const ['Active', 'Past'],
          selectedIndex: 0,
          onChanged: (_) {},
        ),
        const Timeline(
          steps: [
            TimelineStep(title: 'Order placed', state: TimelineState.done),
            TimelineStep(title: 'Delivered', state: TimelineState.upcoming),
          ],
        ),
        const AppListRow(
          leading: AppAvatar(name: 'Mahesh Kumar'),
          title: 'Mahesh Kumar',
          subtitle: 'Customer',
        ),
        const EmptyState(title: 'No bookings yet', message: 'Book one.'),
        ErrorState(error: Exception('boom')),
      ],
    );
    for (final theme in [buildLightTheme(), buildDarkTheme()]) {
      await tester.pumpWidget(
        _host(widgets, theme: theme, textScale: 1.3),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('reduced motion removes shimmer and Lottie loops',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const Column(
          children: [
            SkeletonBox(height: 40),
            LoadingState(),
          ],
        ),
        disableAnimations: true,
      ),
    );
    // A looping animation would make pumpAndSettle time out.
    await tester.pumpAndSettle();
    expect(find.byType(Shimmer), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shimmer runs when motion is allowed', (tester) async {
    await tester.pumpWidget(_host(const SkeletonBox(height: 40)));
    expect(find.byType(Shimmer), findsOneWidget);
  });

  testWidgets('LottieOrIcon shows its fallback under reduced motion',
      (tester) async {
    await tester.pumpWidget(
      _host(
        const LottieOrIcon(
          asset: 'assets/lottie/success.json',
          fallback: Icon(Icons.star, key: Key('fallback')),
        ),
        disableAnimations: true,
      ),
    );
    expect(find.byKey(const Key('fallback')), findsOneWidget);
    expect(find.byType(LottieOrIcon), findsOneWidget);
  });

  testWidgets('SegmentedTabs reports the tapped segment', (tester) async {
    int? picked;
    await tester.pumpWidget(
      _host(
        SegmentedTabs(
          labels: const ['Active', 'Past'],
          selectedIndex: 0,
          onChanged: (index) => picked = index,
        ),
      ),
    );
    await tester.tap(find.text('Past'));
    expect(picked, 1);
  });

  testWidgets('showAppSnack shows the message with its variant icon',
      (tester) async {
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => showAppSnack(
              context,
              'Saved.',
              variant: AppSnackVariant.success,
            ),
            child: const Text('Show'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show'));
    await tester.pump();
    expect(find.text('Saved.'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });

  testWidgets('OtpField reports each change and completion', (tester) async {
    String? last;
    String? completed;
    await tester.pumpWidget(
      _host(
        OtpField(
          onChanged: (value) => last = value,
          onCompleted: (value) => completed = value,
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '123456');
    expect(last, '123456');
    expect(completed, '123456');
  });

  testWidgets('debug gallery renders every widget without exceptions',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: const DesignSystemGallery()),
    );
    // Shimmer and progress indicators loop, so do not wait for them to settle.
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });

  test('AppAvatar.initialsFor uses up to two words', () {
    expect(AppAvatar.initialsFor('Mahesh Kumar'), 'MK');
    expect(AppAvatar.initialsFor('  mahesh  '), 'M');
    expect(AppAvatar.initialsFor('   '), '?');
  });

  test('StatusChip.statusLabel turns snake_case into a sentence', () {
    expect(StatusChip.statusLabel('pending_vendor'), 'Pending vendor');
    expect(StatusChip.statusLabel(''), '');
  });

  test('AppMotion.stagger caps the delay at maxStaggerItems', () {
    expect(AppMotion.stagger(2), AppMotion.staggerStep * 2);
    expect(
      AppMotion.stagger(40),
      AppMotion.staggerStep * AppMotion.maxStaggerItems,
    );
  });
}
