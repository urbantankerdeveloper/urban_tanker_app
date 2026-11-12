import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:urban_tanker_app/app/app_controller.dart';
import 'package:urban_tanker_app/app/providers.dart';
import 'package:urban_tanker_app/models/account.dart';
import 'package:urban_tanker_app/models/booking.dart';
import 'package:urban_tanker_app/models/booking_service_details.dart';
import 'package:urban_tanker_app/models/notification.dart';
import 'package:urban_tanker_app/models/payment.dart';
import 'package:urban_tanker_app/models/session.dart';
import 'package:urban_tanker_app/models/service.dart';
import 'package:urban_tanker_app/screens/booking_details_screen.dart';
import 'package:urban_tanker_app/screens/bookings_screen.dart';
import 'package:urban_tanker_app/screens/common/booking_format.dart';
import 'package:urban_tanker_app/screens/home/booking/booking_form_sheet.dart';
import 'package:urban_tanker_app/screens/home/home_shell.dart';
import 'package:urban_tanker_app/services/api_client.dart';
import 'package:urban_tanker_app/services/realtime_service.dart';

const _booking = Booking(
  id: 'booking-1',
  reference: 'UT-1001',
  status: 'pending_vendor',
  location: '12 Marina Road, Chennai',
  capacity: '5000',
  deliveryDate: null,
  createdAt: null,
  customerName: 'Customer One',
  customerPhone: '+919876543210',
  customerEmail: 'customer@example.com',
  paymentMethod: 'cod',
  paymentStatus: 'cod',
);

Booking _bookingWithStatus(String status) => Booking(
      id: _booking.id,
      reference: _booking.reference,
      status: status,
      location: _booking.location,
      capacity: _booking.capacity,
      deliveryDate: _booking.deliveryDate,
      createdAt: _booking.createdAt,
      customerName: _booking.customerName,
      customerPhone: _booking.customerPhone,
      customerEmail: _booking.customerEmail,
      paymentMethod: _booking.paymentMethod,
      paymentStatus: _booking.paymentStatus,
    );

class _ParityApi extends ApiClient {
  _ParityApi() : super(baseUrl: 'https://example.test/api');

  int cancellationCalls = 0;
  int trackingCalls = 0;
  int notificationCalls = 0;
  int previewCalls = 0;
  int createCalls = 0;
  String? requestedOtpBookingId;
  Future<Booking> Function()? cancelOperation;

  @override
  Future<BookingPage> bookingsPage(
          {int offset = 0, int pageSize = 100}) async =>
      BookingPage(rows: const [_booking]);

  @override
  Future<TrackingSnapshot> bookingTracking(String bookingId) async {
    trackingCalls++;
    return TrackingSnapshot(
      orderId: bookingId,
      status: 'pending_vendor',
      trackingAvailable: false,
    );
  }

  @override
  Future<PaymentReceipt?> getPaymentDetails(String bookingId) async => null;

  @override
  Future<List<TankerService>> services() async => const [];

  @override
  Future<List<AccountRecord>> addresses() async => const [];

  @override
  Future<PhoneVerificationState> phoneVerification() async =>
      const PhoneVerificationState(
        phone: '9876543210',
        verified: true,
        required: false,
      );

  @override
  Future<Map<String, dynamic>> previewBookingQuote({
    required String serviceId,
    required String capacity,
    required String location,
    required String deliveryDate,
    List<BookingServiceDetails>? services,
    String? notes,
    required String paymentMethod,
    String? couponCode,
    String? phone,
    String? phoneVerificationChallengeId,
    double? latitude,
    double? longitude,
  }) async {
    previewCalls++;
    return {
      'quote': {
        'subtotalPaise': 100000,
        'gstPaise': 5000,
        'totalPaise': 105000,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> createBooking({
    required String serviceId,
    required String capacity,
    required String location,
    required String deliveryDate,
    List<BookingServiceDetails>? services,
    String? notes,
    required String paymentMethod,
    String? couponCode,
    String? phone,
    String? phoneVerificationChallengeId,
    double? latitude,
    double? longitude,
    String? idempotencyKey,
  }) async {
    createCalls++;
    return {
      'id': 'booking-created',
      'reference': 'UT-CREATED',
      'status': 'pending_vendor',
      'payment_method': paymentMethod,
    };
  }

  @override
  Future<Booking> cancelBooking(String bookingId) {
    cancellationCalls++;
    return cancelOperation?.call() ??
        Future.value(_bookingWithStatus('cancelled'));
  }

  @override
  Future<({String otp, DateTime expiresAt, bool smsSent})> requestDeliveryOtp(
    String bookingId,
  ) async {
    requestedOtpBookingId = bookingId;
    return (
      otp: '483921',
      expiresAt: DateTime(2026, 11, 12, 6),
      smsSent: false,
    );
  }

  @override
  Future<List<NotificationItem>> notifications(String role) async {
    notificationCalls++;
    return const [];
  }
}

class _TestRealtime extends RealtimeService {
  _TestRealtime()
      : super(
          socketUrl: 'https://example.test',
          readToken: () async => null,
        );

  final StreamController<RealtimeEvent> controller =
      StreamController<RealtimeEvent>.broadcast();

  @override
  Stream<RealtimeEvent> get events => controller.stream;

  @override
  bool get isConnected => true;

  @override
  set isConnected(bool value) {}

  @override
  void joinBooking(String bookingId) {}

  @override
  void leaveBooking(String bookingId) {}

  @override
  void dispose() {
    controller.close();
  }
}

Future<AppController> _controller(_ParityApi api) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(api: api, preferences: preferences)
    ..user = const SessionUser(
      id: 'customer-1',
      name: 'Customer One',
      username: 'customer@example.com',
      email: 'customer@example.com',
      role: WorkspaceRole.customer,
    );
  return controller;
}

Future<void> _pumpDetails(
  WidgetTester tester, {
  required AppController controller,
  required Booking booking,
  Future<void> Function(Booking booking)? onBookAgain,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appControllerProvider.overrideWith((ref) => controller),
        bookingTrackingProvider(booking.id).overrideWith(
          (ref) async => TrackingSnapshot(
            orderId: booking.id,
            status: booking.status,
            trackingAvailable: false,
          ),
        ),
      ],
      child: MaterialApp(
        home: BookingDetailsScreen(
          booking: booking,
          onBookAgain: onBookAgain,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('booking actions and review labels follow web status rules', () {
    expect(canCancelBookingStatus('pending_vendor'), isTrue);
    expect(canCancelBookingStatus('vendor_assigned'), isTrue);
    expect(canCancelBookingStatus('accepted'), isFalse);
    expect(canCancelBookingStatus('delivered'), isFalse);
    expect(canBookAgainStatus('delivered'), isTrue);
    expect(canBookAgainStatus('pending_vendor'), isFalse);
    expect(bookingReviewTitle(1), 'Review Summary');
    expect(bookingReviewTitle(2), 'Review combined Summary');
  });

  testWidgets('booking ID opens details and history has no repeat action',
      (tester) async {
    final api = _ParityApi();
    final controller = await _controller(api);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          sessionUserIdProvider.overrideWithValue('customer-1'),
          appControllerProvider.overrideWith((ref) => controller),
          bookingTrackingProvider(_booking.id).overrideWith(
            (ref) async => TrackingSnapshot(
              orderId: _booking.id,
              status: _booking.status,
              trackingAvailable: false,
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: BookingsScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Book again'), findsNothing);
    await tester.tap(find.text(_booking.reference));
    await tester.pumpAndSettle();

    expect(find.byType(BookingDetailsScreen), findsOneWidget);
  });

  testWidgets('details offer repeat booking only after delivery',
      (tester) async {
    final api = _ParityApi();
    final controller = await _controller(api);
    var repeatedBooking = false;
    await _pumpDetails(
      tester,
      controller: controller,
      booking: _bookingWithStatus('delivered'),
      onBookAgain: (_) async => repeatedBooking = true,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    expect(find.text('Book again'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    await tester.ensureVisible(find.text('Book again'));
    await tester.tap(find.text('Book again'));
    await tester.pump();
    expect(repeatedBooking, isTrue);
  });

  testWidgets('delivery OTP popup shows the code for the selected booking',
      (tester) async {
    final api = _ParityApi();
    final controller = await _controller(api);
    final booking = _bookingWithStatus('arrived');
    await _pumpDetails(
      tester,
      controller: controller,
      booking: booking,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Request delivery OTP'));
    await tester.pumpAndSettle();

    expect(api.requestedOtpBookingId, booking.id);
    expect(find.text('Delivery OTP'), findsOneWidget);
    expect(find.text('Booking ${booking.reference}'), findsOneWidget);
    expect(find.text('483921'), findsOneWidget);
    expect(find.textContaining('SMS was not sent.'), findsOneWidget);
  });

  testWidgets('cancellation shows progress and reports server rejection',
      (tester) async {
    final api = _ParityApi();
    final controller = await _controller(api);
    final cancellation = Completer<Booking>();
    api.cancelOperation = () => cancellation.future;
    await _pumpDetails(
      tester,
      controller: controller,
      booking: _booking,
    );

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -1800));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel booking'));
    await tester.pump();

    expect(api.cancellationCalls, 1);
    expect(find.text('Cancelling…'), findsOneWidget);
    cancellation.completeError(
      const ApiException('This booking has already been accepted.', 409),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('This booking has already been accepted.'),
      findsOneWidget,
    );
  });

  testWidgets('booking confirmation contains summary and returns home',
      (tester) async {
    var returnedHome = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showBookingSuccess(
                context,
                {
                  'id': 'booking-2',
                  'reference': 'UT-2002',
                  'customer_name': 'Customer One',
                  'customer_phone': '+919876543210',
                  'customer_email': 'customer@example.com',
                  'location': '12 Marina Road, Chennai',
                  'scheduled_for': '2026-11-15',
                  'service_details': [
                    {
                      'serviceId': 'water_tanker',
                      'capacity': '5000 litres',
                      'waterType': 'Potable',
                      'tankerCount': '1 tanker',
                      'details': 'Potable water',
                      'deliveryDate': '2026-11-15',
                      'location': '12 Marina Road, Chennai',
                    },
                  ],
                  'service_names': {'water_tanker': 'Water tanker'},
                },
                const {
                  'subtotalPaise': 100000,
                  'gstPaise': 5000,
                  'totalPaise': 105000,
                },
                'cod',
                paidNote: 'Paid ₹1,050.00 via UPI',
                onReturnHome: () => returnedHome = true,
              ),
              child: const Text('Show confirmation'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Show confirmation'));
    await tester.pumpAndSettle();

    expect(find.textContaining('UT-2002'), findsOneWidget);
    expect(find.text('Customer One'), findsOneWidget);
    expect(find.text('+919876543210'), findsOneWidget);
    expect(find.text('customer@example.com'), findsOneWidget);
    expect(find.text('12 Marina Road, Chennai'), findsWidgets);
    expect(find.text('2026-11-15'), findsWidgets);
    expect(find.textContaining('Water type: Potable'), findsOneWidget);
    expect(find.text('Paid ₹1,050.00 via UPI'), findsOneWidget);
    await tester.ensureVisible(find.text('Return home'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Return home'));
    await tester.pumpAndSettle();
    expect(returnedHome, isTrue);
  });

  testWidgets('successful submission closes the draft and returns home',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    final api = _ParityApi();
    final controller = await _controller(api);
    var returnedHome = false;
    var completed = false;
    const tankCleaning = TankerService(
      id: 'tank_cleaning',
      name: 'Tank cleaning',
      description: 'Clean storage tanks',
      category: 'Cleaning',
      capacityOptions: ['1 tank'],
      detailOptions: ['Clean rooftop tank'],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => openBookingForm(
                context,
                controller: controller,
                serviceCatalog: const [tankCleaning],
                onReturnHome: () => returnedHome = true,
                onBookingCompleted: () => completed = true,
              ),
              child: const Text('Open booking'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open booking'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tank cleaning'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 tank').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clean rooftop tank').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      '12 Marina Road, Chennai',
    );
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash on delivery'));
    await tester.pumpAndSettle();
    expect(find.text('Review Summary'), findsOneWidget);
    await tester.tap(find.text('Review Summary'));
    await tester.pumpAndSettle();

    expect(find.text('Review Summary'), findsOneWidget);
    await tester.tap(find.text('Submit booking'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(api.previewCalls, greaterThanOrEqualTo(1));
    await tester.drag(
      find.byKey(const Key('slide-to-confirm')),
      Offset(
          tester.getSize(find.byKey(const Key('slide-to-confirm'))).width, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(api.createCalls, 1);
    expect(find.text('Booking submitted'), findsOneWidget);
    expect(find.text('Leave booking?'), findsNothing);
    await tester.ensureVisible(find.text('Return home'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Return home'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(returnedHome, isTrue);
    expect(completed, isTrue);
    await tester.tap(find.text('Open booking'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Step 1 of 6: Contact'), findsOneWidget);
    expect(find.text('Tank cleaning'), findsNothing);
  });

  testWidgets('accepted booking updates refresh tracking and notify once',
      (tester) async {
    final api = _ParityApi();
    final controller = await _controller(api);
    final realtime = _TestRealtime();
    controller.realtime = realtime;
    addTearDown(realtime.dispose);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiProvider.overrideWithValue(api),
          sessionUserIdProvider.overrideWithValue('customer-1'),
          appControllerProvider.overrideWith((ref) => controller),
          bookingsProvider.overrideWith(
            () => _BookingsTestNotifier(),
          ),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: HomeShell(controller: controller),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    navigatorKey.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => ProviderScope(
          overrides: [
            bookingTrackingProvider(_booking.id).overrideWith(
              (ref) => api.bookingTracking(_booking.id),
            ),
          ],
          child: BookingDetailsScreen(booking: _booking),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final initialTrackingCalls = api.trackingCalls;

    realtime.controller.add(
      const RealtimeEvent(
        'booking.updated',
        {'bookingId': 'booking-1', 'status': 'accepted'},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    realtime.controller.add(
      const RealtimeEvent(
        'booking.updated',
        {'bookingId': 'booking-1', 'status': 'accepted'},
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(api.trackingCalls, greaterThan(initialTrackingCalls));
    expect(
      find.text('Your vendor accepted the booking.'),
      findsOneWidget,
    );
  });
}

class _BookingsTestNotifier extends BookingsNotifier {
  @override
  Future<BookingsState> build() async => const BookingsState(items: [_booking]);
}
