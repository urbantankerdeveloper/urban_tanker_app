import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_controller.dart';
import '../../app/auth_feature_flags.dart';
import '../../app/providers.dart';
import '../../core/design_system/design_system.dart';
import '../../models/booking.dart';
import '../../models/notification.dart';
import '../../models/service.dart';
import '../../models/session.dart';
import '../../models/workspace_navigation.dart';
import '../../services/friendly_error.dart';
import '../../services/realtime_service.dart';
import '../admin/admin_dashboard_screen.dart';
import '../admin/admin_approvals_hub_screen.dart';
import '../admin/admin_operations_screen.dart';
import '../admin/admin_pulse_screen.dart';
import '../admin/admin_reports_screen.dart';
import '../bookings_screen.dart';
import '../customer_account_screen.dart';
import '../dispatcher/alerts_screen.dart';
import '../dispatcher/dispatch_home_screen.dart';
import '../dispatcher/dispatch_screen.dart';
import '../dispatcher/live_screen.dart';
import '../auth/phone_verify_dialog.dart';
import '../profile_dialog.dart';
import '../notification_inbox.dart';
import '../vendor/vendor_earnings_screen.dart';
import '../vendor/fleet/vendor_fleet_screen.dart';
import '../vendor/operations/vendor_operations_screen.dart';
import 'booking/booking_form_sheet.dart';
import 'customer/active_order_widget.dart';
import 'customer/customer_overview.dart';
import 'shell/menu_screen.dart';
import 'shell/notification_routing.dart';
import 'shell/realtime_notice_listener.dart';
import 'shell/role_tabs.dart';
import 'shell/unlock_offer.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  final Set<int> _visitedTabs = {0};
  List<TankerService> _services = const [];
  bool _loadingServices = false;
  bool _bookingFormOpening = false;
  String? _serviceError;
  late Future<List<NotificationItem>>? _notifications;
  StreamSubscription<RealtimeEvent>? _realtimeSubscription;
  final _operationsFocus = ValueNotifier<OperationsFocus?>(null);

  WorkspaceRole get role =>
      widget.controller.user?.role ?? WorkspaceRole.customer;

  @override
  void initState() {
    super.initState();
    _notifications =
        role == WorkspaceRole.customer ||
            role == WorkspaceRole.vendor ||
            role == WorkspaceRole.dispatcher ||
            role == WorkspaceRole.admin
        ? widget.controller.api.notifications(role.name)
        : null;
    if (role == WorkspaceRole.customer) _loadServices();
    _realtimeSubscription = widget.controller.realtime?.events.listen((event) {
      if (!mounted) return;
      switch (event.name) {
        case 'booking.created':
          ref.invalidate(bookingsProvider);
        case 'booking.updated':
        case 'booking.vendor_accepted':
        case 'booking.delivered':
          ref.invalidate(bookingsProvider);
          _refreshBookingTracking(event.payload);
          _reloadNotifications();
        case 'notification.created':
          ref.invalidate(bookingsProvider);
          _reloadNotifications();
        case 'vendor.order.created':
        case 'vendor.order.taken':
        case 'vendor.order.declined':
          // Refresh here too, so a vendor on another tab sees the new order
          // without opening the operations screen first.
          ref
            ..invalidate(vendorOrdersProvider)
            ..invalidate(vendorDashboardProvider);
          _reloadNotifications();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _promptPhoneVerification().then((_) {
          if (mounted) offerUnlockSetup(context, widget.controller);
        }),
      );
    });
  }

  Future<void> _promptPhoneVerification() async {
    if (!AuthFeatureFlags.phoneVerifyDialog || widget.controller.user == null) {
      return;
    }
    if (widget.controller.user?.phoneVerified == null ||
        widget.controller.user?.phoneVerificationRequired == null) {
      final refreshed = await widget.controller.refreshUserProfile();
      if (!mounted) return;
      if (!refreshed) {
        final message = widget.controller.errorMessage;
        if (message != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
        return;
      }
    }
    final user = widget.controller.user;
    if (user?.phoneVerified != false || !mounted) return;
    await showPhoneVerifyDialog(
      context,
      controller: widget.controller,
      allowSkip: user?.phoneVerificationRequired == false,
      initialPhone: user?.phone,
    );
  }

  void _showCustomerProfile() {
    final user = widget.controller.user;
    if (user == null) return;
    showUserProfileDialog(
      context: context,
      api: widget.controller.api,
      name: user.name,
      role: user.role.name,
      username: user.username,
      email: user.email,
      phone: user.phone,
      profilePhotoUrl: ref.read(profileSelfieProvider.future),
      initialProfilePhotoUrl: ref
          .read(profileSelfieProvider)
          .when(
            data: (url) => url,
            loading: () => null,
            error: (_, __) => null,
          ),
      onSaved: (_) async {
        await widget.controller.refreshUserProfile();
        if (!mounted) return;
        ref.invalidate(customerProfileProvider);
        ref.invalidate(profileSelfieProvider);
      },
    );
  }

  void _refreshBookingTracking(dynamic payload) {
    if (role != WorkspaceRole.customer || payload is! Map) return;
    final bookingId =
        (payload['bookingId'] ?? payload['orderId'] ?? payload['id'])
            ?.toString();
    if (bookingId != null && bookingId.isNotEmpty) {
      ref.invalidate(bookingTrackingProvider(bookingId));
    }
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _operationsFocus.dispose();
    super.dispose();
  }

  void _reloadNotifications() {
    if (!mounted ||
        !(role == WorkspaceRole.customer ||
            role == WorkspaceRole.vendor ||
            role == WorkspaceRole.dispatcher ||
            role == WorkspaceRole.admin)) {
      return;
    }
    setState(() {
      _notifications = widget.controller.api.notifications(role.name);
    });
  }

  Future<void> _loadServices({bool bypassCache = false}) async {
    if (bypassCache) {
      widget.controller.api.invalidateReadCache(path: '/customer/services');
    }
    setState(() {
      _loadingServices = true;
      _serviceError = null;
    });
    try {
      _services = await widget.controller.api.services();
    } catch (error) {
      _serviceError = friendlyError(error);
    } finally {
      if (mounted) setState(() => _loadingServices = false);
    }
  }

  Future<void> _createBooking({Booking? previousBooking}) async {
    if (_bookingFormOpening || _services.isEmpty) return;
    setState(() => _bookingFormOpening = true);
    try {
      await openBookingForm(
        context,
        controller: widget.controller,
        serviceCatalog: _services,
        previousBooking: previousBooking,
        onReturnHome: () {
          if (mounted) setState(() => _index = 0);
        },
        onBookingCompleted: () {
          if (mounted) ref.invalidate(bookingsProvider);
        },
      );
    } finally {
      if (mounted) setState(() => _bookingFormOpening = false);
    }
  }

  /// Menu items switch to their tab; admin items also ask the operations
  /// screen to open their section.
  /// Switches to [page] if the current role has a tab for it.
  void _selectPage(ShellPage page) {
    final index = tabsForRole(role).indexWhere((tab) => tab.page == page);
    if (index >= 0) _selectTab(index);
  }

  void _selectTab(int index) {
    _visitedTabs.add(index);
    setState(() => _index = index);
  }

  void _openDestination(WorkspaceNavigationDestination destination) {
    final section = destination.operationsSection;
    _selectTab(destination.index);
    if (section != null) _operationsFocus.value = OperationsFocus(section);
  }

  void _openAdminOperations(OperationsFocus focus) {
    _operationsFocus.value = focus;
    _selectPage(ShellPage.adminOperations);
  }

  void _goHome() {
    _selectTab(0);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _selectNotification(NotificationItem item) {
    if (!hasNotificationTarget(item)) {
      Navigator.of(context).pop();
      showAppSnack(context, 'This notification has no valid destination.');
      return;
    }
    _selectTab(notificationTabIndex(role, item));
    Navigator.of(context).pop();
    unawaited(openNotificationTarget(context, widget.controller, role, item));
  }

  Future<void> _openNotificationInbox() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationInbox(
          controller: widget.controller,
          role: role.name,
          onNotificationSelected: _selectNotification,
        ),
      ),
    );
    _reloadNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.controller.user;
    // The app switches to the auth screen on sign-out; render nothing until then.
    if (user == null) return const SizedBox.shrink();
    final isCustomer = role == WorkspaceRole.customer;
    final tabs = tabsForRole(role);
    final displayName = user.name.trim();
    final appBarTitle = role != WorkspaceRole.customer && displayName.isNotEmpty
        ? displayName
        : titleForRole(role);
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Home',
            onPressed: _goHome,
            icon: const Icon(Icons.home_outlined),
          ),
          _notificationBell(),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: RealtimeNoticeListener(
              events: widget.controller.realtime?.events,
              role: role,
              child: SwipeNavigationArea(
                onSwipeLeft: _index < tabs.length - 1
                    ? () => _selectTab(_index + 1)
                    : null,
                onSwipeRight: _index > 0 ? () => _selectTab(_index - 1) : null,
                child: IndexedStack(
                  index: _index,
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      if (i == _index || _visitedTabs.contains(i))
                        _pageFor(tabs[i].page, user)
                      else
                        const SizedBox.shrink(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isCustomer && _index == 0
          ? FloatingActionButton.extended(
              onPressed:
                  _loadingServices || _services.isEmpty || _bookingFormOpening
                  ? null
                  : _createBooking,
              icon: const Icon(Icons.local_shipping_outlined),
              label: const Text('Book service'),
            )
          : null,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isCustomer && AuthFeatureFlags.newUiEnabled)
            const ActiveOrderWidget(),
          AppBottomNav(
            items: [
              for (final tab in tabs)
                AppNavItem(
                  label: tab.label,
                  icon: tab.icon,
                  selectedIcon: tab.selectedIcon,
                ),
            ],
            selectedIndex: _index,
            onSelected: _selectTab,
          ),
        ],
      ),
    );
  }

  Widget _notificationBell() => FutureBuilder<List<NotificationItem>>(
    future: _notifications,
    builder: (context, snapshot) {
      final unread = snapshot.data?.where((item) => !item.read).length ?? 0;
      return IconButton(
        tooltip: 'Notifications',
        onPressed: _openNotificationInbox,
        icon: Badge(
          isLabelVisible: unread > 0,
          label: Text(unread > 99 ? '99+' : '$unread'),
          child: const Icon(Icons.notifications_none_outlined),
        ),
      );
    },
  );

  Widget _pageFor(ShellPage page, SessionUser user) => switch (page) {
    ShellPage.overview => CustomerOverview(
      user: user,
      services: _services,
      loading: _loadingServices,
      error: _serviceError,
      onRetry: () => _loadServices(bypassCache: true),
      onBook: _services.isEmpty ? null : _createBooking,
      onOpenBookings: () => _selectPage(ShellPage.bookings),
      onOpenAccount: () => _selectPage(ShellPage.account),
      onViewProfile: _showCustomerProfile,
    ),
    ShellPage.bookings => BookingsScreen(
      onBookAgain: (booking) => _createBooking(previousBooking: booking),
      onBook: _services.isEmpty ? null : _createBooking,
    ),
    ShellPage.account => const CustomerAccountScreen(),
    ShellPage.vendorOperations => const VendorOperationsScreen(),
    ShellPage.vendorFleet => const VendorFleetScreen(),
    ShellPage.vendorEarnings => const VendorEarningsScreen(),
    ShellPage.dispatchHome => DispatcherHomeScreen(
      onOpenOrders: () => _selectPage(ShellPage.dispatchDispatch),
      onOpenLive: () => _selectPage(ShellPage.dispatchLive),
      onOpenAlerts: () => _selectPage(ShellPage.dispatchAlerts),
    ),
    ShellPage.dispatchDispatch => const DispatcherDispatchScreen(),
    ShellPage.dispatchLive => const DispatcherLiveScreen(),
    ShellPage.dispatchAlerts => const DispatcherAlertsScreen(),
    ShellPage.adminDashboard => AdminDashboardScreen(
      userName: user.name,
      onOpenOperations: _openAdminOperations,
      onOpenReports: () => _selectPage(ShellPage.adminReports),
    ),
    ShellPage.adminPulse => AdminPulseScreen(onBackToHome: _goHome),
    ShellPage.adminOperations => AdminOperationsScreen(focus: _operationsFocus),
    ShellPage.adminApprovals => AdminApprovalsHubScreen(
      controller: widget.controller,
    ),
    ShellPage.adminReports => const AdminReportsScreen(),
    ShellPage.menu => MenuScreen(
      controller: widget.controller,
      role: role,
      notifications: _notifications,
      onDestination: _openDestination,
      onNotifications: _openNotificationInbox,
      onHome: _goHome,
    ),
  };
}
