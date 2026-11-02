import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'app_controller.dart';
import '../models/booking.dart';
import '../models/account.dart';
import '../models/notification.dart';
import '../models/vendor.dart';
import '../services/api_client.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) {
  throw StateError('AppController must be overridden at startup.');
});

/// Watches only the API client. Theme, biometric and other controller
/// notifications must not re-run the data providers below.
final apiProvider = Provider<ApiClient>((ref) {
  return ref.watch(appControllerProvider.select((c) => c.api));
});

/// Changes only when a different user signs in or out.
final sessionUserIdProvider = Provider<String?>((ref) {
  return ref.watch(appControllerProvider.select((c) => c.user?.id));
});

/// Bookings shown so far. Pages are appended as the user scrolls; a refresh
/// (`ref.invalidate(bookingsProvider)`) starts again from the first page.
class BookingsState {
  const BookingsState({
    required this.items,
    this.nextOffset,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<Booking> items;
  final int? nextOffset;
  final bool loadingMore;
  final bool loadMoreFailed;

  bool get hasMore => nextOffset != null;

  BookingsState copyWith({
    List<Booking>? items,
    int? nextOffset,
    bool? loadingMore,
    bool? loadMoreFailed,
  }) {
    return BookingsState(
      items: items ?? this.items,
      nextOffset: nextOffset ?? this.nextOffset,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
    );
  }
}

class BookingsNotifier extends AsyncNotifier<BookingsState> {
  static const pageSize = 30;

  @override
  Future<BookingsState> build() async {
    ref.watch(sessionUserIdProvider);
    final page = await ref.watch(apiProvider).bookingsPage(pageSize: pageSize);
    return BookingsState(items: page.rows, nextOffset: page.nextOffset);
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null ||
        !current.hasMore ||
        current.loadingMore ||
        current.loadMoreFailed) {
      return;
    }
    state = AsyncData(current.copyWith(loadingMore: true));
    try {
      final page = await ref.read(apiProvider).bookingsPage(
            offset: current.nextOffset!,
            pageSize: pageSize,
          );
      if (!ref.mounted) return;
      state = AsyncData(
        BookingsState(
          items: [...current.items, ...page.rows],
          nextOffset: page.nextOffset,
        ),
      );
    } catch (_) {
      if (!ref.mounted) return;
      state = AsyncData(
        current.copyWith(loadingMore: false, loadMoreFailed: true),
      );
    }
  }

  void retryLoadMore() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(loadMoreFailed: false));
    unawaited(loadMore());
  }
}

final bookingsProvider =
    AsyncNotifierProvider.autoDispose<BookingsNotifier, BookingsState>(
  BookingsNotifier.new,
);

final bookingTrackingProvider =
    FutureProvider.autoDispose.family<TrackingSnapshot, String>((ref, id) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).bookingTracking(id);
});

final customerProfileProvider =
    FutureProvider.autoDispose<CustomerProfile>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).profile();
});

final customerAddressesProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).addresses();
});

final customerWalletProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).wallet();
});

final customerInvoicesProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).invoices();
});

final customerSubscriptionsProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).subscriptions();
});

final customerSupportProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).supportRequests();
});

final customerInvoiceProvider =
    FutureProvider.autoDispose.family<AccountRecord, String>((ref, id) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).invoice(id);
});

final customerSupportRequestProvider =
    FutureProvider.autoDispose.family<AccountRecord, String>((ref, id) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).supportRequest(id);
});

final customerUsageProvider = FutureProvider.autoDispose<CustomerUsage>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).usage();
});

final customerOffersProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).offers();
});

final customerMembershipProvider =
    FutureProvider.autoDispose<AccountRecord?>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).membership();
});

final customerMembershipPlansProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).membershipPlans();
});

final customerContractsProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).contracts();
});

final vendorDashboardProvider =
    FutureProvider.autoDispose<VendorDashboard>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).vendorDashboard();
});

final vendorOrdersProvider =
    FutureProvider.autoDispose<List<VendorOrder>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).vendorOrders();
});

final vendorVehiclesProvider =
    FutureProvider.autoDispose<List<VendorVehicle>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).vendorVehicles();
});

final vendorDriversProvider =
    FutureProvider.autoDispose<List<VendorDriver>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).vendorDrivers();
});

final vendorServicesProvider =
    FutureProvider.autoDispose<List<VendorService>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).vendorServices();
});

final vendorPayoutsProvider =
    FutureProvider.autoDispose<List<VendorPayout>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).vendorPayouts();
});

final vendorOfflineMutationsProvider =
    FutureProvider.autoDispose<List<VendorOfflineMutation>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).vendorOfflineMutations();
});

final adminHealthProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).adminHealth();
});

final dispatcherOrdersProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, DispatcherOrderFilter>((ref, filter) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).adminOrders(
        page: filter.page,
        status: filter.status,
        service: filter.service,
        vendorId: filter.vendorId,
        from: filter.from,
        to: filter.to,
        assigned: filter.assigned,
      );
});

final adminNotificationsProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).adminNotifications();
});

final adminAuditLogsProvider = FutureProvider.autoDispose.family<
    Map<String, dynamic>,
    ({int page, String? action, String? entityType})>((ref, query) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).adminAuditLogs(
        page: query.page,
        action: query.action,
        entityType: query.entityType,
      );
});

final vendorAttendanceProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, DateTime>((ref, date) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).vendorAttendance(date: date);
});

final dispatcherVendorsProvider =
    FutureProvider.autoDispose<List<AccountRecord>>((ref) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).adminVendors();
});

final dispatcherAlertsProvider = FutureProvider.autoDispose
    .family<List<AccountRecord>, String?>((ref, status) {
  ref.watch(sessionUserIdProvider);
  return ref.watch(apiProvider).adminAlerts(status: status);
});

class DispatcherOrderFilter {
  const DispatcherOrderFilter({
    this.page = 1,
    this.status,
    this.service,
    this.vendorId,
    this.from,
    this.to,
    this.assigned,
  });

  final int page;
  final String? status;
  final String? service;
  final String? vendorId;
  final String? from;
  final String? to;
  final bool? assigned;

  @override
  bool operator ==(Object other) =>
      other is DispatcherOrderFilter &&
      page == other.page &&
      status == other.status &&
      service == other.service &&
      vendorId == other.vendorId &&
      from == other.from &&
      to == other.to &&
      assigned == other.assigned;

  @override
  int get hashCode =>
      Object.hash(page, status, service, vendorId, from, to, assigned);
}
