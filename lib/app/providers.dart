import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_controller.dart';
import '../models/booking.dart';
import '../models/account.dart';
import '../models/vendor.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  throw StateError('AppController must be overridden at startup.');
});

final bookingsProvider = FutureProvider.autoDispose<List<Booking>>((ref) {
  final controller = ref.watch(appControllerProvider);
  return controller.api.bookings();
});

final bookingTrackingProvider =
    FutureProvider.autoDispose.family<TrackingSnapshot, String>((ref, id) {
  final controller = ref.watch(appControllerProvider);
  return controller.api.bookingTracking(id);
});

final customerProfileProvider =
    FutureProvider.autoDispose<CustomerProfile>((ref) {
  return ref.watch(appControllerProvider).api.profile();
});

final customerAddressesProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  return ref.watch(appControllerProvider).api.addresses();
});

final customerWalletProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  return ref.watch(appControllerProvider).api.wallet();
});

final customerInvoicesProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  return ref.watch(appControllerProvider).api.invoices();
});

final customerSubscriptionsProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  return ref.watch(appControllerProvider).api.subscriptions();
});

final customerSupportProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  return ref.watch(appControllerProvider).api.supportRequests();
});

final customerInvoiceProvider =
    FutureProvider.autoDispose.family<AccountRecord, String>((ref, id) {
  return ref.watch(appControllerProvider).api.invoice(id);
});

final customerSupportRequestProvider =
    FutureProvider.autoDispose.family<AccountRecord, String>((ref, id) {
  return ref.watch(appControllerProvider).api.supportRequest(id);
});

final customerUsageProvider = FutureProvider.autoDispose<CustomerUsage>((ref) {
  return ref.watch(appControllerProvider).api.usage();
});

final customerOffersProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  return ref.watch(appControllerProvider).api.offers();
});

final customerMembershipProvider =
    FutureProvider.autoDispose<AccountRecord?>((ref) {
  return ref.watch(appControllerProvider).api.membership();
});

final customerMembershipPlansProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  return ref.watch(appControllerProvider).api.membershipPlans();
});

final customerContractsProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  return ref.watch(appControllerProvider).api.contracts();
});

final vendorDashboardProvider =
    FutureProvider.autoDispose<VendorDashboard>((ref) {
  return ref.watch(appControllerProvider).api.vendorDashboard();
});

final vendorOrdersProvider =
    FutureProvider.autoDispose<List<VendorOrder>>((ref) {
  return ref.watch(appControllerProvider).api.vendorOrders();
});

final vendorVehiclesProvider =
    FutureProvider.autoDispose<List<VendorVehicle>>((ref) {
  return ref.watch(appControllerProvider).api.vendorVehicles();
});

final vendorDriversProvider =
    FutureProvider.autoDispose<List<VendorDriver>>((ref) {
  return ref.watch(appControllerProvider).api.vendorDrivers();
});

final vendorServicesProvider =
    FutureProvider.autoDispose<List<VendorService>>((ref) {
  return ref.watch(appControllerProvider).api.vendorServices();
});

final vendorPayoutsProvider =
    FutureProvider.autoDispose<List<VendorPayout>>((ref) {
  return ref.watch(appControllerProvider).api.vendorPayouts();
});

final vendorOfflineMutationsProvider =
    FutureProvider.autoDispose<List<VendorOfflineMutation>>((ref) {
  return ref.watch(appControllerProvider).api.vendorOfflineMutations();
});

final adminHealthProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(appControllerProvider).api.adminHealth();
});

final dispatcherOrdersProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  return ref.watch(appControllerProvider).api.adminOrders();
});

final dispatcherVendorsProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  return ref.watch(appControllerProvider).api.adminVendors();
});

final dispatcherAlertsProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  return ref.watch(appControllerProvider).api.adminAlerts();
});
