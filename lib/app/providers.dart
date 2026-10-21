import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_controller.dart';
import '../models/booking.dart';
import '../models/account.dart';

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
