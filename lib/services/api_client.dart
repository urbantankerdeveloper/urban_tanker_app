import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../models/account.dart';
import '../models/booking.dart';
import '../models/booking_service_details.dart';
import '../models/dispatcher.dart';
import '../models/notification.dart';
import '../models/payment.dart';
import '../models/service.dart';
import '../models/session.dart';
import '../models/vendor.dart';
import 'api/admin_api.dart';
import 'api/api_core.dart';
import 'api/api_transport.dart';
import 'api/api_types.dart';
import 'api/auth_api.dart';
import 'api/customer_api.dart';
import 'api/notification_api.dart';
import 'api/vendor_api.dart';

export 'api/api_types.dart';

/// The API the app talks to. Each endpoint lives in one of the domain classes
/// in `services/api/`, and every HTTP call goes through [ApiCore]. This class
/// keeps the names and signatures the screens and providers use.
class ApiClient implements ApiTransport {
  ApiClient({
    http.Client? client,
    FlutterSecureStorage? storage,
    String? baseUrl,
  }) {
    _core = ApiCore(
      client: client ?? http.Client(),
      storage: storage ?? _defaultStorage,
      baseUrl: _resolveBaseUrl(baseUrl),
      // Reads the token through this instance, so a subclass override applies.
      tokenReader: () => readAccessToken(),
    );
  }

  static const _defaultStorage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
    aOptions: AndroidOptions(resetOnError: true, migrateWithBackup: false),
  );

  static String _resolveBaseUrl(String? value) => (value ??
          const String.fromEnvironment(
            'API_BASE_URL',
            defaultValue: 'https://urban-tanker-backend.onrender.com/api',
          ))
      .replaceFirst(RegExp(r'/$'), '');

  late final ApiCore _core;
  late final AuthApi _auth = AuthApi(this);
  late final CustomerApi _customer = CustomerApi(this);
  late final VendorApi _vendor = VendorApi(this);
  late final AdminApi _admin = AdminApi(this);
  late final NotificationApi _notificationApi = NotificationApi(this);

  String get baseUrl => _core.baseUrl;

  // Transport and session storage.

  @override
  Future<http.Response> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    List<int>? bodyBytes,
    String contentType = 'application/json',
    bool retry = true,
  }) =>
      _core.request(
        method,
        path,
        body: body,
        bodyBytes: bodyBytes,
        contentType: contentType,
        retry: retry,
      );

  @override
  Future<http.Response> sendRequest(
    http.BaseRequest request, {
    Duration timeout = const Duration(seconds: 20),
  }) =>
      _core.sendRequest(request, timeout: timeout);

  /// Evicts cached read-mostly GET responses, optionally for one endpoint.
  ///
  /// Use before invalidating a provider from a manual refresh action.
  @override
  void invalidateReadCache({String? path}) =>
      _core.invalidateReadCache(path: path);

  @override
  Future<void> saveAccessToken(String token) => _core.saveAccessToken(token);

  @override
  Future<void> saveRefreshToken(String token) => _core.saveRefreshToken(token);

  Future<void> clearTokens() => _core.clearTokens();

  /// Keeps the signed-in user profile in secure storage, not SharedPreferences.
  Future<void> saveSessionUser(Map<String, dynamic> user) =>
      _core.saveSessionUser(user);

  Future<Map<String, dynamic>?> readSessionUser() => _core.readSessionUser();

  /// Removes the tokens and the stored user profile.
  Future<void> clearSession() => _core.clearSession();

  Future<String?> readAccessToken() => _core.readAccessToken();

  Future<String?> readRefreshToken() => _core.readRefreshToken();

  /// Revokes the refresh token on the server. Callers ignore failures.
  Future<void> logout(String refreshToken) => _auth.logout(refreshToken);

  // Authentication and preferences.

  Future<AuthResult> login(String credential, String password) =>
      _auth.login(credential, password);

  Future<SignUpOutcome> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? themeMode,
    String role = 'customer',
    String? businessName,
    String? serviceZone,
    double? latitude,
    double? longitude,
    String? selfieJpegBase64,
  }) =>
      _auth.signup(
        email: email,
        password: password,
        name: name,
        phone: phone,
        themeMode: themeMode,
        role: role,
        businessName: businessName,
        serviceZone: serviceZone,
        latitude: latitude,
        longitude: longitude,
        selfieJpegBase64: selfieJpegBase64,
      );

  Future<void> requestPasswordReset(String email) =>
      _auth.requestPasswordReset(email);

  Future<String> requestPhoneAuthOtp(String phone) =>
      _auth.requestPhoneAuthOtp(phone);

  Future<AuthResult> verifyPhoneAuthOtp({
    required String phone,
    required String challengeId,
    required String otp,
    String? name,
  }) =>
      _auth.verifyPhoneAuthOtp(
        phone: phone,
        challengeId: challengeId,
        otp: otp,
        name: name,
      );

  Future<PhoneVerificationState> phoneVerification() =>
      _auth.phoneVerification();

  Future<String> requestPhoneOtp(String phone) => _auth.requestPhoneOtp(phone);

  Future<
      ({
        String? challengeId,
        String? emailChallengeId,
        int resendAfterSeconds
      })> requestBookingOtp(
          {required String phone, String? email}) =>
      _auth.requestBookingOtp(phone: phone, email: email);

  Future<String> requestRegisteredBookingEmailOtp({required String phone}) =>
      _auth.requestRegisteredBookingEmailOtp(phone: phone);

  Future<void> verifyPhoneOtp({
    required String phone,
    String? challengeId,
    String? otp,
    String? email,
    String? emailChallengeId,
    String? emailOtp,
  }) =>
      _auth.verifyPhoneOtp(
        phone: phone,
        challengeId: challengeId,
        otp: otp,
        email: email,
        emailChallengeId: emailChallengeId,
        emailOtp: emailOtp,
      );

  Future<String> requestEmailAuthOtp(String email) =>
      _auth.requestEmailAuthOtp(email);

  Future<AuthResult> verifyEmailAuthOtp({
    required String email,
    required String challengeId,
    required String otp,
    String? name,
    String? phone,
  }) =>
      _auth.verifyEmailAuthOtp(
        email: email,
        challengeId: challengeId,
        otp: otp,
        name: name,
        phone: phone,
      );

  Future<void> updateThemePreference(String themeMode) =>
      _auth.updateThemePreference(themeMode);

  Future<void> saveMpin(String pin) => _auth.saveMpin(pin);

  Future<void> deleteMpin() => _auth.deleteMpin();

  // Customer bookings, tracking and account.

  Future<List<TankerService>> services() => _customer.services();

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
  }) =>
      _customer.createBooking(
        serviceId: serviceId,
        capacity: capacity,
        location: location,
        deliveryDate: deliveryDate,
        services: services,
        notes: notes,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        phone: phone,
        phoneVerificationChallengeId: phoneVerificationChallengeId,
        latitude: latitude,
        longitude: longitude,
        idempotencyKey: idempotencyKey,
      );

  Future<RazorpayOrder> createRazorpayOrder(String bookingId) =>
      _customer.createRazorpayOrder(bookingId);

  Future<String?> verifyRazorpayPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) =>
      _customer.verifyRazorpayPayment(
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );

  Future<void> cancelOnlinePayment(String bookingId, {String? couponCode}) =>
      _customer.cancelOnlinePayment(bookingId, couponCode: couponCode);

  Future<PaymentReceipt?> getPaymentDetails(String bookingId) =>
      _customer.getPaymentDetails(bookingId);

  Future<void> switchBookingToCashOnDelivery(String bookingId) =>
      _customer.switchBookingToCashOnDelivery(bookingId);

  Future<void> switchBookingToOnline(String bookingId) =>
      _customer.switchBookingToOnline(bookingId);

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
  }) =>
      _customer.previewBookingQuote(
        serviceId: serviceId,
        capacity: capacity,
        location: location,
        deliveryDate: deliveryDate,
        services: services,
        notes: notes,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        phone: phone,
        phoneVerificationChallengeId: phoneVerificationChallengeId,
        latitude: latitude,
        longitude: longitude,
      );

  /// Loads every booking by following `nextOffset` from the server.
  Future<List<Booking>> bookings() => _customer.bookings();

  Future<BookingPage> bookingsPage({int offset = 0, int pageSize = 100}) =>
      _customer.bookingsPage(offset: offset, pageSize: pageSize);

  Future<TrackingSnapshot> bookingTracking(String bookingId) =>
      _customer.bookingTracking(bookingId);

  Future<PublicTrackingSnapshot> publicTracking(String token) =>
      _customer.publicTracking(token);

  Future<Booking> cancelBooking(String bookingId) =>
      _customer.cancelBooking(bookingId);

  Future<Booking> rescheduleBooking(
    String bookingId,
    DateTime scheduledFor,
  ) =>
      _customer.rescheduleBooking(bookingId, scheduledFor);

  Future<({String otp, DateTime expiresAt, bool smsSent})> requestDeliveryOtp(
    String bookingId,
  ) =>
      _customer.requestDeliveryOtp(bookingId);

  Future<void> rateBooking(
    String bookingId, {
    required int rating,
    String? review,
  }) =>
      _customer.rateBooking(bookingId, rating: rating, review: review);

  Future<CustomerProfile> profile() => _customer.profile();

  Future<CustomerProfile> updateProfile({
    required String name,
    required String email,
    String? phone,
  }) =>
      _customer.updateProfile(name: name, email: email, phone: phone);

  Future<List<AccountRecord>> addresses() => _customer.addresses();

  Future<AccountRecord> createAddress({
    required String label,
    required String address,
    required String city,
    required String pincode,
    bool isDefault = false,
  }) =>
      _customer.createAddress(
        label: label,
        address: address,
        city: city,
        pincode: pincode,
        isDefault: isDefault,
      );

  Future<AccountRecord> updateAddress(
    String id, {
    String? label,
    String? address,
    String? city,
    String? pincode,
    bool? isDefault,
  }) =>
      _customer.updateAddress(
        id,
        label: label,
        address: address,
        city: city,
        pincode: pincode,
        isDefault: isDefault,
      );

  Future<void> deleteAddress(String id) => _customer.deleteAddress(id);

  Future<List<AccountRecord>> wallet() => _customer.wallet();

  Future<List<AccountRecord>> invoices() => _customer.invoices();

  Future<List<AccountRecord>> subscriptions() => _customer.subscriptions();

  Future<List<AccountRecord>> supportRequests() => _customer.supportRequests();

  Future<AccountRecord> createSupportRequest({
    required String subject,
    required String message,
  }) =>
      _customer.createSupportRequest(subject: subject, message: message);

  Future<AccountRecord> supportRequest(String id) =>
      _customer.supportRequest(id);

  Future<AccountRecord> updateSubscription(String id, String status) =>
      _customer.updateSubscription(id, status);

  Future<AccountRecord> invoice(String id) => _customer.invoice(id);

  Future<List<AccountRecord>> contracts() => _customer.contracts();

  Future<AccountRecord> createContract({
    required String propertyType,
    required String address,
    required double estimate,
  }) =>
      _customer.createContract(
        propertyType: propertyType,
        address: address,
        estimate: estimate,
      );

  Future<CustomerUsage> usage() => _customer.usage();

  Future<List<AccountRecord>> offers() => _customer.offers();

  Future<Map<String, dynamic>> validateCoupon({
    required String code,
    required String serviceCode,
    required double amount,
  }) =>
      _customer.validateCoupon(
        code: code,
        serviceCode: serviceCode,
        amount: amount,
      );

  Future<List<AccountRecord>> membershipPlans() => _customer.membershipPlans();

  Future<AccountRecord?> membership() => _customer.membership();

  Future<AccountRecord> updateMembership(String status) =>
      _customer.updateMembership(status);

  Future<AccountRecord> requestMembership(String planId) =>
      _customer.requestMembership(planId);

  Future<void> uploadCustomerSelfie({required List<int> bytes}) =>
      _customer.uploadCustomerSelfie(bytes: bytes);

  // Vendor workspace.

  Future<VendorDashboard> vendorDashboard() => _vendor.vendorDashboard();

  Future<List<VendorOrder>> vendorOrders() => _vendor.vendorOrders();

  Future<List<VendorVehicle>> vendorVehicles() => _vendor.vendorVehicles();

  Future<List<VendorDriver>> vendorDrivers() => _vendor.vendorDrivers();

  Future<VendorVehicle> createVendorVehicle({
    required String registrationNumber,
    required int capacityLitres,
    bool isActive = true,
  }) =>
      _vendor.createVendorVehicle(
        registrationNumber: registrationNumber,
        capacityLitres: capacityLitres,
        isActive: isActive,
      );

  Future<VendorVehicle> updateVendorVehicle(
    String id, {
    String? registrationNumber,
    int? capacityLitres,
    bool? isActive,
  }) =>
      _vendor.updateVendorVehicle(
        id,
        registrationNumber: registrationNumber,
        capacityLitres: capacityLitres,
        isActive: isActive,
      );

  Future<VendorDriver> createVendorDriver({
    required String name,
    required String mobile,
    required String licenceNumber,
    bool isActive = true,
  }) =>
      _vendor.createVendorDriver(
        name: name,
        mobile: mobile,
        licenceNumber: licenceNumber,
        isActive: isActive,
      );

  Future<VendorDriver> updateVendorDriver(
    String id, {
    String? name,
    String? mobile,
    String? licenceNumber,
    bool? isActive,
  }) =>
      _vendor.updateVendorDriver(
        id,
        name: name,
        mobile: mobile,
        licenceNumber: licenceNumber,
        isActive: isActive,
      );

  Future<VendorPayout> requestVendorPayout({
    required double amount,
    DateTime? periodStart,
    DateTime? periodEnd,
  }) =>
      _vendor.requestVendorPayout(
        amount: amount,
        periodStart: periodStart,
        periodEnd: periodEnd,
      );

  Future<VendorOrder> verifyVendorDelivery({
    required String orderId,
    String? otp,
    String? proofPath,
  }) =>
      _vendor.verifyVendorDelivery(
        orderId: orderId,
        otp: otp,
        proofPath: proofPath,
      );

  Future<void> updateVendorLocation({
    required String bookingId,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) =>
      _vendor.updateVendorLocation(
        bookingId: bookingId,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );

  Future<List<VendorPayout>> vendorPayouts() => _vendor.vendorPayouts();

  Future<List<Map<String, dynamic>>> vendorComplaints() =>
      _vendor.vendorComplaints();

  Future<Map<String, dynamic>> updateVendorComplaint({
    required String id,
    required String status,
    String? resolution,
  }) =>
      _vendor.updateVendorComplaint(
        id: id,
        status: status,
        resolution: resolution,
      );

  Future<Map<String, dynamic>> createVendorComplaint({
    required String bookingId,
    required String subject,
    required String message,
  }) =>
      _vendor.createVendorComplaint(
        bookingId: bookingId,
        subject: subject,
        message: message,
      );

  Future<List<Map<String, dynamic>>> vendorDocuments() =>
      _vendor.vendorDocuments();

  Future<Map<String, dynamic>> createVendorDocument({
    required String documentType,
    required String objectKey,
    String? expiresOn,
  }) =>
      _vendor.createVendorDocument(
        documentType: documentType,
        objectKey: objectKey,
        expiresOn: expiresOn,
      );

  Future<String> uploadVendorFile({
    required String fileName,
    required String contentType,
    required List<int> bytes,
  }) =>
      _vendor.uploadVendorFile(
        fileName: fileName,
        contentType: contentType,
        bytes: bytes,
      );

  Future<Map<String, dynamic>> updateVendorDocument({
    required String id,
    String? objectKey,
    String? documentType,
    String? expiresOn,
  }) =>
      _vendor.updateVendorDocument(
        id: id,
        objectKey: objectKey,
        documentType: documentType,
        expiresOn: expiresOn,
      );

  Future<Map<String, dynamic>> updateVendorAttendance({
    required String driverId,
    required String status,
    DateTime? date,
  }) =>
      _vendor.updateVendorAttendance(
        driverId: driverId,
        status: status,
        date: date,
      );

  Future<List<Map<String, dynamic>>> vendorAttendance({
    String? driverId,
    DateTime? date,
  }) =>
      _vendor.vendorAttendance(driverId: driverId, date: date);

  Future<List<VendorService>> vendorServices() => _vendor.vendorServices();

  Future<Map<String, dynamic>> updateVendorServiceAvailability({
    required String serviceCode,
    required bool enabled,
  }) =>
      _vendor.updateVendorServiceAvailability(
        serviceCode: serviceCode,
        enabled: enabled,
      );

  Future<VendorOrder> transitionVendorOrder(
    String orderId, {
    required String action,
    String? status,
    String? reason,
    String? vehicleId,
    String? driverId,
  }) =>
      _vendor.transitionVendorOrder(
        orderId,
        action: action,
        status: status,
        reason: reason,
        vehicleId: vehicleId,
        driverId: driverId,
      );

  Future<List<VendorOfflineMutation>> vendorOfflineMutations() =>
      _vendor.vendorOfflineMutations();

  Future<VendorOfflineMutation> queueVendorMutation({
    required String mutationType,
    required String entityType,
    String? entityId,
    required Map<String, dynamic> payload,
  }) =>
      _vendor.queueVendorMutation(
        mutationType: mutationType,
        entityType: entityType,
        entityId: entityId,
        payload: payload,
      );

  Future<VendorOfflineMutation> retryVendorMutation(String id) =>
      _vendor.retryVendorMutation(id);

  Future<void> discardVendorMutation(String id) =>
      _vendor.discardVendorMutation(id);

  // Admin and dispatcher workspaces.

  Future<List<AccountRecord>> adminVendors() => _admin.adminVendors();

  Future<List<AccountRecord>> adminCustomers() => _admin.adminCustomers();

  Future<List<AccountRecord>> adminCoupons() => _admin.adminCoupons();

  Future<List<AdminFleetVehicle>> adminVehicles() => _admin.adminVehicles();

  Future<List<AdminFleetDriver>> adminDrivers() => _admin.adminDrivers();

  Future<AdminFleetVehicle> createAdminVehicle({
    required String vendorId,
    required String registrationNumber,
    required int capacityLitres,
    List<String> supportedServices = const [],
  }) =>
      _admin.createAdminVehicle(
        vendorId: vendorId,
        registrationNumber: registrationNumber,
        capacityLitres: capacityLitres,
        supportedServices: supportedServices,
      );

  Future<AdminFleetDriver> createAdminDriver({
    required String vendorId,
    required String name,
    required String mobile,
    required String licenceNumber,
  }) =>
      _admin.createAdminDriver(
        vendorId: vendorId,
        name: name,
        mobile: mobile,
        licenceNumber: licenceNumber,
      );

  Future<void> updateAdminVehicleStatus(
    String id, {
    required String verification,
    required bool isActive,
  }) =>
      _admin.updateAdminVehicleStatus(
        id,
        verification: verification,
        isActive: isActive,
      );

  Future<void> updateAdminDriverStatus(
    String id, {
    required String verification,
    required bool isActive,
  }) =>
      _admin.updateAdminDriverStatus(
        id,
        verification: verification,
        isActive: isActive,
      );

  Future<Map<String, dynamic>> adminHealth() => _admin.adminHealth();

  Future<void> updateVendorVerification(String id, String status) =>
      _admin.updateVendorVerification(id, status);

  Future<Map<String, dynamic>> adminOrders({
    int page = 1,
    String? status,
    String? service,
    String? vendorId,
    String? from,
    String? to,
    bool? assigned,
    int pageSize = 25,
  }) =>
      _admin.adminOrders(
        page: page,
        status: status,
        service: service,
        vendorId: vendorId,
        from: from,
        to: to,
        assigned: assigned,
        pageSize: pageSize,
      );

  Future<List<DispatcherOrder>> dispatcherOrderRows({
    int page = 1,
    String? status,
    String? service,
    String? vendorId,
    String? from,
    String? to,
    bool? assigned,
  }) =>
      _admin.dispatcherOrderRows(
        page: page,
        status: status,
        service: service,
        vendorId: vendorId,
        from: from,
        to: to,
        assigned: assigned,
      );

  Future<List<AccountRecord>> adminAlerts({String? status}) =>
      _admin.adminAlerts(status: status);

  Future<AccountRecord> updateDispatcherAlert(String id, String status) =>
      _admin.updateDispatcherAlert(id, status);

  Future<List<DispatcherAlert>> dispatcherAlertRows() =>
      _admin.dispatcherAlertRows();

  Future<List<AccountRecord>> dispatcherVendors() => _admin.dispatcherVendors();

  Future<AccountRecord> dispatcherAssignOrder(
    String orderId, {
    String? vendorId,
    String? vehicleId,
    String? driverId,
  }) =>
      _admin.dispatcherAssignOrder(
        orderId,
        vendorId: vendorId,
        vehicleId: vehicleId,
        driverId: driverId,
      );

  Future<AccountRecord> dispatcherUpdateStatus(String orderId, String status) =>
      _admin.dispatcherUpdateStatus(orderId, status);

  Future<AccountRecord> dispatcherCancelOrder(String orderId, String reason) =>
      _admin.dispatcherCancelOrder(orderId, reason);

  Future<AccountRecord> assignAdminOrder(
    String id, {
    String? vendorId,
    String? vehicleId,
    String? driverId,
  }) =>
      _admin.assignAdminOrder(
        id,
        vendorId: vendorId,
        vehicleId: vehicleId,
        driverId: driverId,
      );

  Future<AccountRecord> updateAdminOrderStatus(String id, String status) =>
      _admin.updateAdminOrderStatus(id, status);

  Future<AccountRecord> cancelAdminOrder(String id, String reason) =>
      _admin.cancelAdminOrder(id, reason);

  Future<AccountRecord> adminVendor(String id) => _admin.adminVendor(id);

  Future<AccountRecord> createAdminVendor(Map<String, dynamic> body) =>
      _admin.createAdminVendor(body);

  Future<AccountRecord> updateAdminVendor(
    String id,
    Map<String, dynamic> body,
  ) =>
      _admin.updateAdminVendor(id, body);

  Future<void> deleteAdminVendor(String id) => _admin.deleteAdminVendor(id);

  Future<AccountRecord> adminCustomer(String id) => _admin.adminCustomer(id);

  Future<AccountRecord> createAdminCustomer(Map<String, dynamic> body) =>
      _admin.createAdminCustomer(body);

  Future<AccountRecord> updateAdminCustomer(
    String id,
    Map<String, dynamic> body,
  ) =>
      _admin.updateAdminCustomer(id, body);

  Future<void> deleteAdminCustomer(String id) => _admin.deleteAdminCustomer(id);

  Future<AccountRecord> createAdminCoupon(Map<String, dynamic> body) =>
      _admin.createAdminCoupon(body);

  Future<AccountRecord> updateAdminCoupon(
    String id,
    Map<String, dynamic> body,
  ) =>
      _admin.updateAdminCoupon(id, body);

  Future<void> deleteAdminCoupon(String id) => _admin.deleteAdminCoupon(id);

  Future<List<AccountRecord>> adminServices() => _admin.adminServices();

  Future<AccountRecord> createAdminService(Map<String, dynamic> body) =>
      _admin.createAdminService(body);

  Future<AccountRecord> updateAdminService(
    String id,
    Map<String, dynamic> body,
  ) =>
      _admin.updateAdminService(id, body);

  Future<List<AccountRecord>> adminPayouts() => _admin.adminPayouts();

  Future<List<AccountRecord>> adminPartnerApplications({String? status}) =>
      _admin.adminPartnerApplications(status: status);

  Future<AccountRecord> reviewPartnerApplication(
    String id, {
    required String status,
    String? reviewNote,
  }) =>
      _admin.reviewPartnerApplication(
        id,
        status: status,
        reviewNote: reviewNote,
      );

  Future<Map<String, dynamic>> adminReport(Map<String, dynamic> body) =>
      _admin.adminReport(body);

  Future<void> adminStorageCleanup() => _admin.adminStorageCleanup();

  Future<void> sendAdminNotification(Map<String, dynamic> body) =>
      _admin.sendAdminNotification(body);

  Future<Map<String, dynamic>> adminPayoutPage({int page = 1}) =>
      _admin.adminPayoutPage(page: page);

  Future<AccountRecord> updateAdminPayout(String id, String status) =>
      _admin.updateAdminPayout(id, status);

  Future<Map<String, dynamic>> adminAuditLogs({
    int page = 1,
    String? actorId,
    String? action,
    String? entityType,
  }) =>
      _admin.adminAuditLogs(
        page: page,
        actorId: actorId,
        action: action,
        entityType: entityType,
      );

  // Notifications and devices.

  Future<List<NotificationItem>> notifications(String role) =>
      _notificationApi.notifications(role);

  Future<List<NotificationItem>> adminNotifications() =>
      _notificationApi.adminNotifications();

  Future<void> markAdminNotificationRead(String id) =>
      _notificationApi.markAdminNotificationRead(id);

  Future<void> markNotificationRead(String role, String id) =>
      _notificationApi.markNotificationRead(role, id);

  Future<void> markAllNotificationsRead(String role) =>
      _notificationApi.markAllNotificationsRead(role);

  Future<void> registerDevice({
    required String token,
    required String platform,
  }) =>
      _notificationApi.registerDevice(token: token, platform: platform);

  Future<void> unregisterDevice(String token) =>
      _notificationApi.unregisterDevice(token);
}
